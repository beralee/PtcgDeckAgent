#pragma once

#include <chrono>
#include <condition_variable>
#include <functional>
#include <future>
#include <mutex>
#include <stdexcept>
#include <thread>
#include <type_traits>

namespace ptcgai {

// One reusable native thread per loaded actor. No Godot objects cross this seam.
class InferenceWorker {
public:
    using Clock = std::chrono::steady_clock;
    template<class T> struct Result { T value; int64_t elapsed_us; };
    template<class T> struct Ticket {
        std::future<Clock::time_point> started;
        std::future<Result<T>> completed;
    };

    InferenceWorker() : thread([this] {
        for (;;) {
            std::function<void()> next;
            {
                std::unique_lock<std::mutex> lock(mutex);
                ready.wait(lock, [this] { return stopping || static_cast<bool>(job); });
                if (stopping && !job) return;
                next = std::move(job);
                job = nullptr;
            }
            next();
        }
    }) {}

    ~InferenceWorker() {
        {
            std::lock_guard<std::mutex> lock(mutex);
            stopping = true;
        }
        ready.notify_one();
        if (thread.joinable()) thread.join();
    }

    template<class F> auto submit(F function) -> Ticket<std::invoke_result_t<F>> {
        using T = std::invoke_result_t<F>;
        auto started = std::make_shared<std::promise<Clock::time_point>>();
        auto task = std::make_shared<std::packaged_task<Result<T>()>>([started, function = std::move(function)]() mutable {
            const auto begin = Clock::now();
            started->set_value(begin);
            T value = function();
            const auto elapsed = std::chrono::duration_cast<std::chrono::microseconds>(Clock::now() - begin).count();
            return Result<T>{std::move(value), elapsed};
        });
        Ticket<T> result{started->get_future(), task->get_future()};
        {
            std::lock_guard<std::mutex> lock(mutex);
            if (stopping || job) throw std::runtime_error("inference worker busy");
            job = [task] { (*task)(); };
        }
        ready.notify_one();
        return result;
    }

private:
    std::mutex mutex;
    std::condition_variable ready;
    bool stopping = false;
    std::function<void()> job;
    std::thread thread;
};
} // namespace ptcgai

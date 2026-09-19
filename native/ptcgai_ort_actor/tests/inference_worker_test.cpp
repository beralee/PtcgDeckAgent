#ifdef NDEBUG
#undef NDEBUG
#endif
#include "../src/inference_worker.hpp"
#include <cassert>
#include <iostream>

int main() {
    ptcgai::InferenceWorker worker;
    auto first = worker.submit([] { return std::this_thread::get_id(); });
    first.started.get();
    auto first_result = first.completed.get();
    auto second = worker.submit([] { return std::this_thread::get_id(); });
    second.started.get();
    // A descheduled consumer must not turn a fast completed inference into a
    // timeout. The old implementation measured time on the consumer instead.
    std::this_thread::sleep_for(std::chrono::milliseconds(60));
    auto second_result = second.completed.get();
    assert(first_result.value == second_result.value);
    assert(second_result.elapsed_us < 25000);
    auto failure = worker.submit([]() -> int { throw std::runtime_error("fixture"); });
    failure.started.get();
    bool caught = false;
    try { failure.completed.get(); } catch (const std::runtime_error &) { caught = true; }
    assert(caught);
    auto recovery = worker.submit([] { return 29; });
    recovery.started.get();
    assert(recovery.completed.get().value == 29);
    auto slow = worker.submit([] { std::this_thread::sleep_for(std::chrono::milliseconds(40)); return 0; });
    const auto began = slow.started.get();
    assert(slow.completed.wait_until(began + std::chrono::milliseconds(1)) == std::future_status::timeout);
    assert(slow.completed.get().elapsed_us >= 25000);
    std::cout << "PASS persistent thread, producer timing, exception, recovery and real deadline\n";
}

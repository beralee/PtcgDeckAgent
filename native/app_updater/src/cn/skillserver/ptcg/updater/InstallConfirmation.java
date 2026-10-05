package cn.skillserver.ptcg.updater;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import java.lang.ref.WeakReference;

/** System callbacks only queue consent; a resumed game Activity owns its launch. */
final class InstallConfirmation {
    private static WeakReference<Activity> foreground = new WeakReference<>(null);
    private static Intent pending;
    private static String token = "";
    private static int session = -1;
    private static boolean external;

    static synchronized void resumed(Activity activity) {
        foreground = new WeakReference<>(activity);
        launch();
    }
    static synchronized void paused(Activity activity) {
        if (foreground.get() == activity) foreground.clear();
    }
    static synchronized void offer(Context context, String owner, int id, Intent intent) {
        offer(context, owner, id, intent, false);
    }
    static synchronized void offerExternal(Context context, String owner, Intent intent) {
        offer(context, owner, -1, intent, true);
    }
    private static void offer(Context context, String owner, int id, Intent intent, boolean systemInstaller) {
        if (!UpdateStatus.active(context, owner)) return;
        token = owner;
        session = id;
        external = systemInstaller;
        pending = new Intent(intent);
        UpdateStatus.set(context, owner, "awaiting_foreground");
        launch();
    }
    static synchronized void clear() {
        pending = null; token = ""; session = -1; external = false;
    }
    private static void launch() {
        final Activity activity = foreground.get();
        if (activity == null || pending == null) return;
        activity.runOnUiThread(() -> {
            synchronized (InstallConfirmation.class) {
                if (foreground.get() != activity || activity.isFinishing() || activity.isDestroyed() || pending == null) return;
                String owner = token;
                int id = session;
                Intent confirmation = pending;
                boolean systemInstaller = external;
                clear();
                if (!UpdateStatus.active(activity, owner)) return;
                // Keep consent in the foreground task; no background receiver launch
                // or orphan MULTIPLE_TASK installer can outlive an abandoned retry.
                confirmation.setFlags(confirmation.getFlags() & ~(Intent.FLAG_ACTIVITY_NEW_TASK
                    | Intent.FLAG_ACTIVITY_MULTIPLE_TASK | Intent.FLAG_ACTIVITY_NEW_DOCUMENT));
                UpdateStatus.set(activity, owner, systemInstaller ? "awaiting_external" : "awaiting_user");
                try {
                    if (systemInstaller) activity.startActivityForResult(confirmation, 7418);
                    else activity.startActivity(confirmation);
                }
                catch (RuntimeException error) {
                    UpdateStatus.set(activity, owner, "failed_confirmation");
                    if (id >= 0) try { activity.getPackageManager().getPackageInstaller().abandonSession(id); } catch (RuntimeException ignored) { }
                }
            }
        });
    }
}

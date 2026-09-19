package cn.skillserver.ptcg.updater;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageInstaller;

/** Explicit PendingIntent recipient. No exported component or file provider. */
public final class InstallResultReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context context, Intent intent) {
        int result = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE);
        if (result == PackageInstaller.STATUS_PENDING_USER_ACTION) {
            Intent confirmation = intent.getParcelableExtra(Intent.EXTRA_INTENT);
            if (confirmation == null) { UpdateStatus.set(context, "failed_confirmation"); return; }
            try {
                confirmation.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                context.startActivity(confirmation);
                UpdateStatus.set(context, "awaiting_user");
            } catch (RuntimeException error) { UpdateStatus.set(context, "failed_confirmation"); }
        } else if (result == PackageInstaller.STATUS_SUCCESS) {
            UpdateStatus.set(context, "success");
        } else if (result == PackageInstaller.STATUS_FAILURE_ABORTED) {
            UpdateStatus.set(context, "cancelled");
        } else {
            UpdateStatus.set(context, "failed_" + result);
        }
    }
}

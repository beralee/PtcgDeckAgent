package cn.skillserver.ptcg.updater;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageInstaller;

/** Explicit PendingIntent recipient. Consent is launched only by the foreground game. */
public final class InstallResultReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context context, Intent intent) {
        String token = intent.getStringExtra("ptcg_token");
        if (token == null || !UpdateStatus.active(context, token)) return;
        int result = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE);
        if (result == PackageInstaller.STATUS_PENDING_USER_ACTION) {
            Intent confirmation = intent.getParcelableExtra(Intent.EXTRA_INTENT);
            if (confirmation == null) { failConfirmation(context, intent, token); return; }
            InstallConfirmation.offer(context, token, intent.getIntExtra("ptcg_session", -1), confirmation);
        } else {
            int legacy = intent.getIntExtra("android.content.pm.extra.LEGACY_STATUS", 0);
            boolean verification = intent.hasExtra("android.content.pm.extra.DEVELOPER_VERIFICATION_FAILURE_REASON");
            android.util.Log.i("PtcgAppUpdater", "Install result=" + result + " legacy=" + legacy + " verification=" + verification);
            UpdateStatus.set(context, token, InstallOutcome.status(result, legacy, verification));
        }
    }
    private void failConfirmation(Context context, Intent intent, String token) {
        UpdateStatus.set(context, token, "failed_confirmation");
        int id = intent.getIntExtra("ptcg_session", -1);
        if (id >= 0) try { context.getPackageManager().getPackageInstaller().abandonSession(id); } catch (RuntimeException ignored) { }
    }
}

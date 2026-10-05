package cn.skillserver.ptcg.updater;

import android.app.DownloadManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.database.Cursor;

/** System broadcasts only report transport or return to the game, never install. */
public final class DownloadReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context context, Intent intent) {
        long id = context.getSharedPreferences(AppDownloads.PREFS, Context.MODE_PRIVATE).getLong("id", -1);
        if (id < 0) return;
        if (DownloadManager.ACTION_NOTIFICATION_CLICKED.equals(intent.getAction())) {
            long[] ids = intent.getLongArrayExtra(DownloadManager.EXTRA_NOTIFICATION_CLICK_DOWNLOAD_IDS);
            if (ids == null) return;
            for (long tapped : ids) if (tapped == id) {
                Intent open = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
                if (open != null) context.startActivity(open.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP).putExtra("ptcg_update_open", true));
                return;
            }
        } else if (DownloadManager.ACTION_DOWNLOAD_COMPLETE.equals(intent.getAction()) && intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -2) == id) {
            DownloadManager manager = (DownloadManager) context.getSystemService(Context.DOWNLOAD_SERVICE);
            try (Cursor row = manager.query(new DownloadManager.Query().setFilterById(id))) {
                if (row != null && row.moveToFirst()) {
                    int status = row.getInt(row.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS));
                    if (status == DownloadManager.STATUS_SUCCESSFUL || status == DownloadManager.STATUS_FAILED) DownloadNotice.completed(context, status == DownloadManager.STATUS_SUCCESSFUL);
                }
            } catch (RuntimeException ignored) { }
        }
    }
}

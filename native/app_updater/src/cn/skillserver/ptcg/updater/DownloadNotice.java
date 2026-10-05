package cn.skillserver.ptcg.updater;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

final class DownloadNotice {
    private static final int ID = 7418;
    static void clear(Context c) { ((NotificationManager)c.getSystemService(Context.NOTIFICATION_SERVICE)).cancel(ID); }
    static boolean enabled(Context c) { return ((NotificationManager)c.getSystemService(Context.NOTIFICATION_SERVICE)).areNotificationsEnabled(); }
    static void completed(Context c, boolean success) {
        NotificationManager manager = (NotificationManager)c.getSystemService(Context.NOTIFICATION_SERVICE);
        if (!enabled(c)) return;
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(new NotificationChannel("game_updates", "游戏更新", NotificationManager.IMPORTANCE_DEFAULT));
        Intent open = c.getPackageManager().getLaunchIntentForPackage(c.getPackageName());
        if (open == null) return;
        open.putExtra("ptcg_update_open", true).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        PendingIntent tap = PendingIntent.getActivity(c, ID, open, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        Notification.Builder notice = Build.VERSION.SDK_INT >= 26 ? new Notification.Builder(c, "game_updates") : new Notification.Builder(c);
        notice.setSmallIcon(android.R.drawable.stat_sys_download_done).setContentTitle(success ? "更新包已下载" : "更新下载未完成")
            .setContentText(success ? "点击返回游戏，校验后即可安装" : "点击返回游戏查看原因并重试")
            .setContentIntent(tap).setAutoCancel(true).setOnlyAlertOnce(true);
        try { manager.notify(ID, notice.build()); } catch (SecurityException ignored) { }
    }
}

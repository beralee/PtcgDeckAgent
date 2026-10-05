package cn.skillserver.ptcg.updater;

import android.content.Context;
import android.content.SharedPreferences;

/** Durable identity rejects callbacks from cancelled or replaced attempts. */
final class UpdateStatus {
    private static SharedPreferences prefs(Context c) { return c.getSharedPreferences("ptcg_app_update", Context.MODE_PRIVATE); }
    static synchronized void begin(Context c, String token) {
        prefs(c).edit().putString("token", token).putString("status", "preparing").putString("shared_apk", "").putInt("session", -1).commit();
    }
    static synchronized boolean active(Context c, String token) { return !token.isEmpty() && token.equals(prefs(c).getString("token", "")); }
    static synchronized void set(Context c, String token, String value) {
        if (!active(c, token)) return;
        SharedPreferences.Editor edit = prefs(c).edit().putString("status", value);
        if (!(value.equals("preparing") || value.equals("permission_required") || value.equals("awaiting_user") || value.equals("awaiting_foreground") || value.equals("awaiting_external"))) edit.putString("token", "").putInt("session", -1).putString("shared_apk", "");
        edit.commit();
    }
    static synchronized boolean session(Context c, String token, int id) {
        if (!active(c, token)) return false;
        prefs(c).edit().putInt("session", id).commit();
        return true;
    }
    static synchronized int cancel(Context c, String status) {
        int id = prefs(c).getInt("session", -1);
        prefs(c).edit().putString("token", "").putInt("session", -1).putString("shared_apk", "").putString("status", status).commit();
        return id;
    }
    static synchronized boolean share(Context c, String token, String name) {
        if (!active(c, token) || !name.matches("[0-9a-f]{64}\\.apk")) return false;
        prefs(c).edit().putString("shared_apk", name).commit();
        return true;
    }
    static String sharedApk(Context c) { return prefs(c).getString("shared_apk", ""); }
    static String get(Context c) { return prefs(c).getString("status", "idle"); }
}

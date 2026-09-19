package cn.skillserver.ptcg.updater;

import android.content.Context;

final class UpdateStatus {
    static void set(Context context, String value) {
        context.getSharedPreferences("ptcg_app_update", Context.MODE_PRIVATE).edit().putString("status", value).apply();
    }
    static String get(Context context) {
        return context.getSharedPreferences("ptcg_app_update", Context.MODE_PRIVATE).getString("status", "idle");
    }
}

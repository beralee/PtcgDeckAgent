package cn.skillserver.ptcg.updater;

import android.app.DownloadManager;
import android.content.Context;
import android.content.SharedPreferences;
import android.content.pm.ApplicationInfo;
import android.database.Cursor;
import android.net.Uri;
import android.os.Environment;
import org.json.JSONObject;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.security.MessageDigest;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** The OS owns transport and its progress notification, independently of Godot. */
final class AppDownloads {
    static final String PREFS = "ptcg_system_download";
    static final String FIXED_APK_URL = "https://ptcg.skillserver.cn/dist/downloads/ptcgdeckagent-android.apk";
    private static final long MAX_BYTES = 2147483648L;
    private final Context context;
    private final DownloadManager manager;
    private final SharedPreferences prefs;
    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private volatile long copyingId = -1;

    AppDownloads(Context c) {
        context = c.getApplicationContext();
        manager = (DownloadManager) context.getSystemService(Context.DOWNLOAD_SERVICE);
        prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    private static JSONObject report(String state, long bytes, int reason) {
        JSONObject value = new JSONObject();
        try { value.put("state", state).put("downloaded", Math.max(0, bytes)).put("reason", reason); }
        catch (Exception ignored) { }
        return value;
    }

    static boolean allowedUrl(Context context, String url) {
        if (url.matches("https://ptcg\\.skillserver\\.cn/[^\\s\\\\]*")) return true;
        // Local HTTP is confined to the separate, debug-signed validation app.
        return context.getPackageName().equals("cn.skillserver.ptcg.updatelab")
            && (context.getApplicationInfo().flags & ApplicationInfo.FLAG_DEBUGGABLE) != 0
            && url.matches("http://(127\\.0\\.0\\.1|10\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}|192\\.168\\.[0-9]{1,3}\\.[0-9]{1,3}|172\\.(1[6-9]|2[0-9]|3[01])\\.[0-9]{1,3}\\.[0-9]{1,3}):[0-9]{2,5}/(good|slow|drop|truncated|corrupt|invalid|missing|stall)");
    }

    synchronized String start(String url, String hash, String size, String title) {
        return start(url, hash, size, title, "");
    }

    synchronized String startFixed(String url, String key, String version, String title) {
        try {
            boolean lab = context.getPackageName().equals("cn.skillserver.ptcg.updatelab") && allowedUrl(context, url);
            if ((!FIXED_APK_URL.equals(url) && !lab) || !version.matches("[0-9]{1,8}\\.[0-9]{1,8}\\.[0-9]{1,8}(\\.[0-9]{1,8})?")) return report("failed", 0, -1).toString();
            String expectedKey = hex(MessageDigest.getInstance("SHA-256").digest((url + "\n" + version).getBytes(StandardCharsets.UTF_8)));
            if (!key.equals(expectedKey)) return report("failed", 0, -1).toString();
            return start(url, key, "0", title, version);
        } catch (Exception error) { return report("failed", 0, -1).toString(); }
    }

    private synchronized String start(String url, String hash, String size, String title, String fixedVersion) {
        try {
            long expected = Long.parseLong(size);
            if (manager == null || !hash.matches("[0-9a-f]{64}") || expected < 0 || (expected == 0 && fixedVersion.isEmpty()) || expected > MAX_BYTES || !allowedUrl(context, url)) return report("failed", 0, -1).toString();
            if (hash.equals(prefs.getString("hash", "")) && prefs.getLong("id", -1) >= 0) {
                JSONObject existing = statusObject(hash);
                if (!existing.optString("state").equals("failed") && !existing.optString("state").equals("missing")) return existing.toString();
            }
            cancel("");
            File destination = destination(hash);
            destination.getParentFile().mkdirs();
            if (destination.getParentFile().getUsableSpace() < expected * 2 + 32L * 1024 * 1024) return report("failed", 0, 1006).toString();
            if (destination.exists() && !destination.delete()) return report("failed", 0, 1001).toString();
            DownloadManager.Request request = new DownloadManager.Request(Uri.parse(url));
            request.setTitle("游戏更新 · " + title);
            request.setDescription("下载完成后返回游戏校验并安装");
            // The downloaded file is never opened directly by an APK installer.
            request.setMimeType("application/octet-stream");
            request.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE);
            request.setAllowedOverMetered(true);
            request.setAllowedOverRoaming(false);
            request.addRequestHeader("Accept-Encoding", "identity");
            request.addRequestHeader("Cache-Control", "no-cache");
            request.addRequestHeader("Pragma", "no-cache");
            request.setDestinationInExternalFilesDir(context, Environment.DIRECTORY_DOWNLOADS, "app_updates/" + hash + ".download");
            if (!prefs.edit().putString("hash", hash).putLong("size", expected).putString("url", url).putString("fixed_version", fixedVersion).remove("resolved").remove("error").remove("validation_error").commit()) return report("failed", 0, 1001).toString();
            long id = manager.enqueue(request);
            if (!prefs.edit().putLong("id", id).commit()) {
                manager.remove(id);
                return report("failed", 0, 1001).toString();
            }
            DownloadNotice.clear(context);
            return statusObject(hash).toString();
        } catch (Exception error) { return report("failed", 0, -1).toString(); }
    }

    private File destination(String hash) { return new File(context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS), "app_updates/" + hash + ".download"); }
    private File cached(String hash) { return new File(context.getFilesDir(), "app_updates/" + hash + ".apk"); }

    synchronized void cancel(String hash) {
        if (!hash.isEmpty() && !hash.equals(prefs.getString("hash", ""))) return;
        long id = prefs.getLong("id", -1);
        prefs.edit().clear().commit(); // Invalidate the importer before removing bytes.
        if (id >= 0 && manager != null) try { manager.remove(id); } catch (RuntimeException ignored) { }
        DownloadNotice.clear(context);
    }

    synchronized String status(String hash) { return statusObject(hash).toString(); }

    private JSONObject statusObject(String hash) {
        long id = prefs.getLong("id", -1);
        if (manager == null || id < 0 || !hash.equals(prefs.getString("hash", ""))) return report("missing", 0, 0);
        if (prefs.contains("error")) {
            JSONObject failed = report("failed", 0, prefs.getInt("error", 1001));
            try { failed.put("validation_error", prefs.getString("validation_error", "")); } catch (Exception ignored) { }
            return failed;
        }
        try (Cursor row = manager.query(new DownloadManager.Query().setFilterById(id))) {
            if (row == null || !row.moveToFirst()) return report("missing", 0, 0);
            int state = row.getInt(row.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS));
            int reason = row.getInt(row.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON));
            long bytes = row.getLong(row.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR));
            long total = row.getLong(row.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES));
            long expected = prefs.getLong("size", 0);
            String fixedVersion = prefs.getString("fixed_version", "");
            boolean fixed = !fixedVersion.isEmpty();
            if (bytes > MAX_BYTES || total > MAX_BYTES || (!fixed && (bytes > expected || (total > 0 && total != expected)))) return report("failed", bytes, -2);
            if (state == DownloadManager.STATUS_FAILED) return report("failed", bytes, reason);
            if (state == DownloadManager.STATUS_SUCCESSFUL) {
                File target = cached(hash);
                if (fixed && prefs.contains("resolved")) {
                    JSONObject resolved = new JSONObject(prefs.getString("resolved", "{}"));
                    if (target.isFile() && target.length() == resolved.optLong("size", -1)) return report("completed", target.length(), 0).put("resolved", resolved);
                } else if (!fixed && target.isFile() && target.length() == expected) return report("completed", expected, 0);
                if (copyingId != id) {
                    copyingId = id;
                    final long actualExpected = fixed ? bytes : expected;
                    worker.execute(() -> importCompleted(id, hash, actualExpected, fixedVersion));
                }
                return report("importing", bytes, 0).put("total", total);
            }
            return report(state == DownloadManager.STATUS_PAUSED ? "paused" : state == DownloadManager.STATUS_PENDING ? "pending" : "running", bytes, reason).put("total", total);
        } catch (Exception error) { return report("failed", 0, -1); }
    }

    private void importCompleted(long id, String hash, long expected, String fixedVersion) {
        File target = cached(hash);
        File partial = new File(target.getParentFile(), hash + ".system.part.apk");
        try {
            if (expected <= 0 || expected > MAX_BYTES) throw new Exception("size");
            target.getParentFile().mkdirs();
            if (target.getParentFile().getUsableSpace() < expected + 16L * 1024 * 1024) throw new Exception("space");
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            try (FileInputStream input = new FileInputStream(destination(hash)); FileOutputStream output = new FileOutputStream(partial)) {
                byte[] buffer = new byte[262144]; int read; long total = 0;
                while ((read = input.read(buffer)) != -1) {
                    if (prefs.getLong("id", -1) != id) throw new Exception("cancelled");
                    total += read;
                    if (total > expected) throw new Exception("size");
                    output.write(buffer, 0, read);
                    digest.update(buffer, 0, read);
                }
                if (total != expected) throw new Exception("size");
                output.getFD().sync();
            }
            JSONObject resolved = null;
            if (!fixedVersion.isEmpty()) {
                long build = PtcgAppUpdater.validateCandidate(context, partial, fixedVersion);
                resolved = new JSONObject().put("size", expected).put("sha256", hex(digest.digest())).put("build", build).put("version", fixedVersion);
            }
            synchronized (this) {
                if (prefs.getLong("id", -1) != id) throw new Exception("cancelled");
                if (!partial.renameTo(target)) throw new Exception("write");
                if (resolved != null && !prefs.edit().putString("resolved", resolved.toString()).commit()) throw new Exception("write");
            }
        } catch (Exception error) {
            synchronized (this) {
                if (prefs.getLong("id", -1) == id) prefs.edit().putInt("error", "space".equals(error.getMessage()) ? 1006 : 1001).putString("validation_error", error.getMessage() == null ? "" : error.getMessage()).commit();
            }
        } finally {
            partial.delete();
            if (copyingId == id) copyingId = -1;
        }
    }

    private static String hex(byte[] bytes) {
        StringBuilder value = new StringBuilder();
        for (byte b : bytes) value.append(String.format("%02x", b & 255));
        return value.toString();
    }
}

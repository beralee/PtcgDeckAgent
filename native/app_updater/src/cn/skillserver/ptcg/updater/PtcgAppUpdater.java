package cn.skillserver.ptcg.updater;

import android.app.Activity;
import android.app.PendingIntent;
import android.content.Intent;
import android.content.Context;
import android.content.ClipData;
import android.content.pm.PackageInfo;
import android.content.pm.PackageInstaller;
import android.content.pm.PackageManager;
import android.content.pm.Signature;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;
import java.io.File;
import java.io.FileInputStream;
import java.io.OutputStream;
import java.security.MessageDigest;
import java.util.Arrays;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** Same-package/same-signer installation; Android owns consent and replacement. */
public final class PtcgAppUpdater extends GodotPlugin {
    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private boolean recovered;
    private Request pending;
    private boolean awaitingPermission;
    private AppDownloads downloads;
    private synchronized AppDownloads downloads() {
        if (downloads == null) downloads = new AppDownloads(getActivity());
        return downloads;
    }
    @UsedByGodot public String startDownload(String url, String hash, String size, String title) {
        Activity a = getActivity();
        if (a == null) return "{\"state\":\"failed\"}";
        requestDownloadNotice(a);
        return downloads().start(url, hash, size, title);
    }
    private void requestDownloadNotice(Activity a) {
        if (Build.VERSION.SDK_INT >= 33 && !DownloadNotice.enabled(a)
            && !a.getPreferences(0).getBoolean("update_notice_asked", false)) {
            a.getPreferences(0).edit().putBoolean("update_notice_asked", true).apply();
            a.runOnUiThread(() -> a.requestPermissions(new String[]{"android.permission.POST_NOTIFICATIONS"}, 7420));
        }
    }
    @UsedByGodot public String getDownloadStatus(String hash) { return downloads().status(hash); }
    @UsedByGodot public String startFixedDownload(String url, String key, String version, String title) {
        Activity a = getActivity();
        if (a == null) return "{\"state\":\"failed\"}";
        requestDownloadNotice(a);
        return downloads().startFixed(url, key, version, title);
    }
    @UsedByGodot public void cancelDownload(String hash) { downloads().cancel(hash); }
    @UsedByGodot public boolean updateNotificationsEnabled() { return getActivity() != null && DownloadNotice.enabled(getActivity()); }
    @UsedByGodot public void openUpdateNotificationSettings() {
        Activity a = getActivity();
        if (a != null) a.runOnUiThread(() -> {
            try {
                Intent settings = Build.VERSION.SDK_INT >= 26
                    ? new Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, a.getPackageName())
                    : new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:" + a.getPackageName()));
                a.startActivity(settings);
            }
            catch (RuntimeException ignored) { }
        });
    }
    private static final class Request {
        final File file; final String hash, token; final long bytes, build;
        final boolean external;
        Request(File f, String h, long n, long b, boolean e) { file=f; hash=h; bytes=n; build=b; external=e; token=UUID.randomUUID().toString(); }
    }
    public PtcgAppUpdater(Godot godot) { super(godot); }
    @Override public String getPluginName() { return "PtcgAppUpdater"; }
    @Override public synchronized void onMainResume() {
        Activity a = getActivity();
        if (a == null) return;
        InstallConfirmation.resumed(a);
        // Some OEM settings pages omit the activity result after granting access.
        if (awaitingPermission && pending != null && UpdateStatus.active(a, pending.token)
            && (Build.VERSION.SDK_INT < 26 || a.getPackageManager().canRequestPackageInstalls())) {
            awaitingPermission = false;
            startRequestedInstall(a, pending);
        }
    }
    @Override public void onMainPause() { InstallConfirmation.paused(getActivity()); }
    private void abandon(Activity a, int id) {
        if (id >= 0) try { a.getPackageManager().getPackageInstaller().abandonSession(id); } catch (RuntimeException ignored) { }
    }
    private synchronized void recover(Activity a) {
        if (recovered) return;
        recovered = true;
        String state = UpdateStatus.get(a);
        if (state.equals("preparing") || state.equals("permission_required") || state.equals("awaiting_user") || state.equals("awaiting_foreground") || state.equals("awaiting_external")) abandon(a, UpdateStatus.cancel(a, "cancelled_restart"));
    }
    @UsedByGodot public synchronized String getUpdateStatus() {
        Activity a = getActivity();
        if (a == null) return "failed_activity";
        recover(a);
        return UpdateStatus.get(a);
    }
    @UsedByGodot public synchronized String cancelUpdate() {
        Activity a = getActivity();
        if (a == null) return "failed_activity";
        recover(a);
        awaitingPermission = false; pending = null;
        InstallConfirmation.clear();
        abandon(a, UpdateStatus.cancel(a, "cancelled"));
        return "cancelled";
    }
    @UsedByGodot public synchronized String installUpdate(String path, String sha256, String bytes, String build) {
        return install(path, sha256, bytes, build, false);
    }
    @UsedByGodot public synchronized String installUpdateWithSystemInstaller(String path, String sha256, String bytes, String build) {
        return install(path, sha256, bytes, build, true);
    }
    private String install(String path, String sha256, String bytes, String build, boolean external) {
        Activity a = getActivity();
        if (a == null) return "failed_activity";
        recover(a);
        if (pending != null && UpdateStatus.active(a, pending.token)) return UpdateStatus.get(a);
        try {
            File file = new File(path).getCanonicalFile();
            File owner = new File(a.getFilesDir(), "app_updates").getCanonicalFile();
            if (!owner.equals(file.getParentFile()) || !sha256.matches("[0-9a-f]{64}") || !file.getName().equals(sha256 + ".apk")) return "failed_path";
            long size = Long.parseLong(bytes), code = Long.parseLong(build);
            if (size <= 0 || size > 2147483648L || code <= 0 || code > 2100000000L) return "failed_metadata";
            if (!file.isFile() || !file.canRead()) return "failed_file_missing";
            final Request request = new Request(file, sha256, size, code, external);
            pending = request;
            UpdateStatus.begin(a, request.token);
            if (Build.VERSION.SDK_INT >= 26 && !a.getPackageManager().canRequestPackageInstalls()) {
                UpdateStatus.set(a, request.token, "permission_required");
                awaitingPermission = true;
                a.runOnUiThread(() -> {
                    if (!UpdateStatus.active(a, request.token)) return;
                    try { a.startActivityForResult(new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:" + a.getPackageName())), 7419); }
                    catch (RuntimeException error) { UpdateStatus.set(a, request.token, "failed_permission_settings"); }
                });
                return "permission_required";
            }
            startRequestedInstall(a, request);
            return "preparing";
        } catch (Exception error) { return "failed_metadata"; }
    }
    @Override public synchronized void onMainActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == 7418) {
            Activity a = getActivity();
            if (a == null || pending == null || !pending.external || !UpdateStatus.active(a, pending.token)) return;
            String status = "external_cancelled";
            // RESULT_OK alone is not proof of an installed version.
            try {
                PackageInfo info = a.getPackageManager().getPackageInfo(a.getPackageName(), 0);
                long code = Build.VERSION.SDK_INT >= 28 ? info.getLongVersionCode() : info.versionCode;
                if (code >= pending.build) status = "success";
                else if (resultCode != Activity.RESULT_CANCELED) status = "failed_external";
            } catch (Exception ignored) { status = "failed_external"; }
            a.revokeUriPermission(VerifiedApkProvider.uri(a, pending.token, pending.hash), Intent.FLAG_GRANT_READ_URI_PERMISSION);
            UpdateStatus.set(a, pending.token, status);
            return;
        }
        if (requestCode != 7419 || !awaitingPermission || pending == null) return;
        awaitingPermission = false;
        Activity a = getActivity();
        if (a == null || !UpdateStatus.active(a, pending.token)) return;
        if (Build.VERSION.SDK_INT < 26 || a.getPackageManager().canRequestPackageInstalls()) startRequestedInstall(a, pending);
        else UpdateStatus.set(a, pending.token, "permission_denied");
    }
    private void startRequestedInstall(Activity a, Request request) {
        if (request.external) startSystemInstaller(a, request);
        else startSession(a, request);
    }
    private void startSystemInstaller(final Activity a, final Request request) {
        UpdateStatus.set(a, request.token, "preparing");
        worker.execute(() -> {
            try {
                require(UpdateStatus.active(a, request.token), "cancelled");
                require(request.file.isFile() && request.file.canRead(), "failed_file_missing");
                require(request.file.length() == request.bytes, "failed_integrity");
                require(validateCandidate(a, request.file, "") == request.build, "failed_version");
                MessageDigest hash = MessageDigest.getInstance("SHA-256");
                try (FileInputStream input = new FileInputStream(request.file)) {
                    byte[] buffer = new byte[262144]; int read; long total = 0;
                    while ((read = input.read(buffer)) != -1) {
                        require(UpdateStatus.active(a, request.token), "cancelled");
                        total += read; require(total <= request.bytes, "failed_integrity");
                        hash.update(buffer, 0, read);
                    }
                    require(total == request.bytes, "failed_integrity");
                }
                StringBuilder hex = new StringBuilder();
                for (byte value : hash.digest()) hex.append(String.format("%02x", value & 255));
                require(request.hash.equals(hex.toString()), "failed_integrity");
                require(UpdateStatus.share(a, request.token, request.file.getName()), "cancelled");
                Uri uri = VerifiedApkProvider.uri(a, request.token, request.hash);
                Intent intent = new Intent(Intent.ACTION_INSTALL_PACKAGE).setDataAndType(uri, "application/vnd.android.package-archive")
                    .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION).putExtra(Intent.EXTRA_RETURN_RESULT, true);
                intent.setClipData(ClipData.newRawUri("Verified game update", uri));
                InstallConfirmation.offerExternal(a, request.token, intent);
            } catch (Exception error) { UpdateStatus.set(a, request.token, preparationFailure(error)); }
        });
    }
    private static void require(boolean condition, String code) throws Exception { if (!condition) throw new Exception(code); }
    static long validateCandidate(Context context, File file, String expectedVersion) throws Exception {
        PackageManager manager = context.getPackageManager();
        int flags = Build.VERSION.SDK_INT >= 28 ? PackageManager.GET_SIGNING_CERTIFICATES : PackageManager.GET_SIGNATURES;
        PackageInfo installed = manager.getPackageInfo(context.getPackageName(), flags);
        PackageInfo candidate = manager.getPackageArchiveInfo(file.getPath(), flags);
        require(candidate != null, "failed_package_invalid");
        require(context.getPackageName().equals(candidate.packageName), "failed_identity");
        long build = Build.VERSION.SDK_INT >= 28 ? candidate.getLongVersionCode() : candidate.versionCode;
        long current = Build.VERSION.SDK_INT >= 28 ? installed.getLongVersionCode() : installed.versionCode;
        require(build > current && build <= 2100000000L, "failed_version");
        require(expectedVersion.isEmpty() || expectedVersion.equals(candidate.versionName), "failed_version");
        Signature[] oldSigners = Build.VERSION.SDK_INT >= 28 ? (installed.signingInfo == null ? null : installed.signingInfo.getApkContentsSigners()) : installed.signatures;
        Signature[] newSigners = Build.VERSION.SDK_INT >= 28 ? (candidate.signingInfo == null ? null : candidate.signingInfo.getApkContentsSigners()) : candidate.signatures;
        require(oldSigners != null && newSigners != null && oldSigners.length > 0 && oldSigners.length == newSigners.length && Arrays.asList(oldSigners).containsAll(Arrays.asList(newSigners)), "failed_signer");
        return build;
    }
    private void startSession(final Activity a, final Request request) {
        UpdateStatus.set(a, request.token, "preparing");
        worker.execute(() -> {
            int sessionId = -1;
            PackageInstaller installer = a.getPackageManager().getPackageInstaller();
            try {
                require(UpdateStatus.active(a, request.token), "cancelled");
                require(request.file.isFile() && request.file.canRead(), "failed_file_missing");
                require(request.file.length() == request.bytes, "failed_integrity");
                require(request.file.getParentFile().getUsableSpace() > request.bytes + 32L * 1024 * 1024, "failed_storage");
                require(validateCandidate(a, request.file, "") == request.build, "failed_version");
                PackageInstaller.SessionParams params = new PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL);
                params.setAppPackageName(a.getPackageName()); params.setSize(request.bytes);
                if (Build.VERSION.SDK_INT >= 31) params.setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_REQUIRED);
                if (Build.VERSION.SDK_INT >= 33) params.setPackageSource(PackageInstaller.PACKAGE_SOURCE_DOWNLOADED_FILE);
                sessionId = installer.createSession(params);
                require(UpdateStatus.session(a, request.token, sessionId), "cancelled");
                try (PackageInstaller.Session session = installer.openSession(sessionId)) {
                    try (FileInputStream input = new FileInputStream(request.file);
                         OutputStream output = session.openWrite("base.apk", 0, request.bytes)) {
                        MessageDigest hash = MessageDigest.getInstance("SHA-256");
                        byte[] buffer = new byte[262144]; int read; long total = 0;
                        while ((read = input.read(buffer)) != -1) {
                            require(UpdateStatus.active(a, request.token), "cancelled");
                            total += read; require(total <= request.bytes, "failed_integrity");
                            hash.update(buffer, 0, read); output.write(buffer, 0, read);
                        }
                        StringBuilder hex = new StringBuilder();
                        for (byte value : hash.digest()) hex.append(String.format("%02x", value & 255));
                        require(total == request.bytes && request.hash.equals(hex.toString()), "failed_integrity");
                        session.fsync(output);
                    } // Close the Android pipe exactly once, before commit.
                    Intent result = new Intent(a, InstallResultReceiver.class).setAction(a.getPackageName() + ".UPDATE_RESULT").putExtra("ptcg_token", request.token).putExtra("ptcg_session", sessionId);
                    int pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT;
                    if (Build.VERSION.SDK_INT >= 31) pendingFlags |= PendingIntent.FLAG_MUTABLE;
                    PendingIntent callback = PendingIntent.getBroadcast(a, sessionId, result, pendingFlags);
                    synchronized (PtcgAppUpdater.this) {
                        require(UpdateStatus.active(a, request.token), "cancelled");
                        session.commit(callback.getIntentSender());
                    }
                }
            } catch (Exception error) {
                abandon(a, sessionId);
                UpdateStatus.set(a, request.token, preparationFailure(error));
            }
        });
    }
    private static String preparationFailure(Exception error) {
        String code = error.getMessage();
        if (code != null && Arrays.asList("cancelled", "failed_file_missing", "failed_integrity", "failed_storage", "failed_package_invalid", "failed_identity", "failed_version", "failed_signer").contains(code)) return code;
        android.util.Log.w("PtcgAppUpdater", "Installation preparation failed: " + error.getClass().getSimpleName());
        return "failed_install";
    }
}

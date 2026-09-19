package cn.skillserver.ptcg.updater;

import android.app.Activity;
import android.app.PendingIntent;
import android.content.Intent;
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
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** Sideloaded, same-package/same-signer updates. The Android installer owns consent. */
public final class PtcgAppUpdater extends GodotPlugin {
    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private volatile boolean busy;
    private volatile boolean awaitingPermission;
    private String pendingPath, pendingHash;
    private long pendingBytes, pendingBuild;

    public PtcgAppUpdater(Godot godot) { super(godot); }
    @Override public String getPluginName() { return "PtcgAppUpdater"; }

    @UsedByGodot public String getUpdateStatus() {
        Activity activity = getActivity();
        return activity == null ? "failed_activity" : UpdateStatus.get(activity);
    }

    @UsedByGodot public synchronized String installUpdate(String path, String sha256, String bytes, String build) {
        Activity activity = getActivity();
        if (activity == null) return "failed_activity";
        if (busy) return getUpdateStatus();
        try {
            File file = new File(path).getCanonicalFile();
            File owner = new File(activity.getFilesDir(), "app_updates").getCanonicalFile();
            // Godot user:// is Activity.filesDir on native Android.
            if (!file.getParentFile().equals(owner) || !file.getName().equals(sha256 + ".apk") || !sha256.matches("[0-9a-f]{64}")) return "failed_path";
            pendingBytes = Long.parseLong(bytes); pendingBuild = Long.parseLong(build);
            if (pendingBytes <= 0 || pendingBytes > 2147483648L || pendingBuild <= 0) return "failed_metadata";
            pendingPath = file.getPath(); pendingHash = sha256;
            busy = true;
            if (Build.VERSION.SDK_INT >= 26 && !activity.getPackageManager().canRequestPackageInstalls()) {
                UpdateStatus.set(activity, "permission_required");
                activity.runOnUiThread(() -> {
                    try {
                        awaitingPermission = true;
                        activity.startActivityForResult(new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                            Uri.parse("package:" + activity.getPackageName())), 7419);
                    } catch (RuntimeException error) { busy = false; awaitingPermission = false; UpdateStatus.set(activity, "failed_permission_settings"); }
                });
                return "permission_required";
            }
            startSession();
            return "preparing";
        } catch (Exception error) { busy = false; return "failed_metadata"; }
    }

    @Override public void onMainActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode != 7419 || !awaitingPermission) return;
        awaitingPermission = false;
        Activity activity = getActivity();
        if (activity != null && (Build.VERSION.SDK_INT < 26 || activity.getPackageManager().canRequestPackageInstalls())) startSession();
        else { busy = false; if (activity != null) UpdateStatus.set(activity, "permission_denied"); }
    }

    private void startSession() {
        final Activity activity = getActivity();
        if (activity == null) { busy = false; return; }
        UpdateStatus.set(activity, "preparing");
        worker.execute(() -> {
            int sessionId = -1;
            PackageInstaller installer = activity.getPackageManager().getPackageInstaller();
            try {
                File file = new File(pendingPath);
                if (file.length() != pendingBytes) throw new Exception("size");
                PackageManager manager = activity.getPackageManager();
                int flags = Build.VERSION.SDK_INT >= 28 ? PackageManager.GET_SIGNING_CERTIFICATES : PackageManager.GET_SIGNATURES;
                PackageInfo installed = manager.getPackageInfo(activity.getPackageName(), flags);
                PackageInfo candidate = manager.getPackageArchiveInfo(file.getPath(), flags);
                if (candidate == null || !activity.getPackageName().equals(candidate.packageName)) throw new Exception("identity");
                long candidateBuild = Build.VERSION.SDK_INT >= 28 ? candidate.getLongVersionCode() : candidate.versionCode;
                long currentBuild = Build.VERSION.SDK_INT >= 28 ? installed.getLongVersionCode() : installed.versionCode;
                if (candidateBuild != pendingBuild || candidateBuild <= currentBuild) throw new Exception("version");
                Signature[] oldSigners = Build.VERSION.SDK_INT >= 28 ? installed.signingInfo.getApkContentsSigners() : installed.signatures;
                Signature[] newSigners = Build.VERSION.SDK_INT >= 28 ? candidate.signingInfo.getApkContentsSigners() : candidate.signatures;
                if (oldSigners == null || newSigners == null || oldSigners.length != newSigners.length || !Arrays.asList(oldSigners).containsAll(Arrays.asList(newSigners))) throw new Exception("signer");
                PackageInstaller.SessionParams params = new PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL);
                params.setAppPackageName(activity.getPackageName()); params.setSize(pendingBytes);
                if (Build.VERSION.SDK_INT >= 31) params.setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_REQUIRED);
                sessionId = installer.createSession(params);
                try (PackageInstaller.Session session = installer.openSession(sessionId);
                     FileInputStream input = new FileInputStream(file);
                     OutputStream output = session.openWrite("base.apk", 0, pendingBytes)) {
                    MessageDigest hash = MessageDigest.getInstance("SHA-256");
                    byte[] buffer = new byte[262144]; int read; long total = 0;
                    while ((read = input.read(buffer)) != -1) {
                        total += read;
                        if (total > pendingBytes) throw new Exception("size");
                        hash.update(buffer, 0, read); output.write(buffer, 0, read);
                    }
                    StringBuilder hex = new StringBuilder();
                    for (byte value : hash.digest()) hex.append(String.format("%02x", value & 255));
                    if (total != pendingBytes || !pendingHash.equals(hex.toString())) throw new Exception("integrity");
                    session.fsync(output);
                    output.close();
                    Intent result = new Intent(activity, InstallResultReceiver.class).setAction(activity.getPackageName() + ".UPDATE_RESULT");
                    int pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT;
                    if (Build.VERSION.SDK_INT >= 31) pendingFlags |= PendingIntent.FLAG_MUTABLE;
                    PendingIntent pending = PendingIntent.getBroadcast(activity, sessionId, result, pendingFlags);
                    session.commit(pending.getIntentSender());
                }
            } catch (Exception error) {
                if (sessionId >= 0) try { installer.abandonSession(sessionId); } catch (RuntimeException ignored) { }
                // Stable diagnostics only; no local paths or arbitrary Android messages.
                UpdateStatus.set(activity, "failed_install");
            } finally { busy = false; }
        });
    }
}

package cn.skillserver.ptcg.updater;

import android.content.ContentProvider;
import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.MatrixCursor;
import android.net.Uri;
import android.os.ParcelFileDescriptor;
import android.provider.OpenableColumns;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.util.List;

/** One verified APK, one active random token, read-only URI grants. No directory sharing. */
public final class VerifiedApkProvider extends ContentProvider {
    static Uri uri(Context context, String token, String hash) {
        return new Uri.Builder().scheme("content").authority(context.getPackageName() + ".app_update_apk")
            .appendPath(token).appendPath(hash + ".apk").build();
    }
    @Override public boolean onCreate() { return true; }
    private File file(Uri uri) throws FileNotFoundException {
        Context context = getContext();
        List<String> parts = uri.getPathSegments();
        if (context == null || !"content".equals(uri.getScheme())
            || !(context.getPackageName() + ".app_update_apk").equals(uri.getAuthority())
            || parts.size() != 2 || !parts.get(1).matches("[0-9a-f]{64}\\.apk")
            || !UpdateStatus.active(context, parts.get(0))
            || !parts.get(1).equals(UpdateStatus.sharedApk(context))) throw new FileNotFoundException("Inactive update");
        try {
            File root = new File(context.getFilesDir(), "app_updates").getCanonicalFile();
            File file = new File(root, parts.get(1)).getCanonicalFile();
            if (!root.equals(file.getParentFile()) || !file.isFile()) throw new FileNotFoundException("Missing update");
            return file;
        } catch (IOException error) { throw new FileNotFoundException("Invalid update"); }
    }
    @Override public ParcelFileDescriptor openFile(Uri uri, String mode) throws FileNotFoundException {
        if (!"r".equals(mode)) throw new FileNotFoundException("Read only");
        return ParcelFileDescriptor.open(file(uri), ParcelFileDescriptor.MODE_READ_ONLY);
    }
    @Override public String getType(Uri uri) { return "application/vnd.android.package-archive"; }
    @Override public Cursor query(Uri uri, String[] projection, String selection, String[] args, String sortOrder) {
        final File apk;
        try { apk = file(uri); } catch (FileNotFoundException error) { throw new SecurityException("Inactive update"); }
        String[] columns = projection == null ? new String[]{OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE} : projection;
        MatrixCursor cursor = new MatrixCursor(columns, 1);
        Object[] values = new Object[columns.length];
        for (int i = 0; i < columns.length; i++) {
            if (OpenableColumns.DISPLAY_NAME.equals(columns[i])) values[i] = "PtcgDeckAgent-update.apk";
            else if (OpenableColumns.SIZE.equals(columns[i])) values[i] = apk.length();
        }
        cursor.addRow(values);
        return cursor;
    }
    @Override public Uri insert(Uri uri, ContentValues values) { throw new SecurityException("Read only"); }
    @Override public int update(Uri uri, ContentValues values, String selection, String[] args) { throw new SecurityException("Read only"); }
    @Override public int delete(Uri uri, String selection, String[] args) { throw new SecurityException("Read only"); }
}

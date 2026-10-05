package cn.skillserver.ptcg.updater;

import android.content.pm.PackageInstaller;

/** Keep system rejection distinct from an explicit in-game cancellation. */
final class InstallOutcome {
    static String status(int result, int legacy, boolean verificationFailure) {
        if (result == PackageInstaller.STATUS_SUCCESS) return "success";
        // INSTALL_FAILED_VERIFICATION_FAILURE (-22) can arrive as ABORTED on OEM ROMs.
        if (legacy == -22 || verificationFailure) return "failed_verification";
        return "failed_" + result;
    }
}

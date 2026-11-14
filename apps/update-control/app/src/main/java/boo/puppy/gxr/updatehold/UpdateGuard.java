package boo.puppy.gxr.updatehold;

import android.Manifest;
import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Build;
import android.provider.Settings;
import android.util.Log;

final class UpdateGuard {
    static final String KEY = "ota_disable_automatic_update";
    private static final String TAG = "GxrUpdateHold";

    private UpdateGuard() {}

    static boolean hasPermission(Context context) {
        return context.checkSelfPermission(Manifest.permission.WRITE_SECURE_SETTINGS)
                == PackageManager.PERMISSION_GRANTED;
    }

    static boolean enforce(Context context) {
        if (!"xrvst2".equals(Build.DEVICE) || !hasPermission(context)) {
            return false;
        }
        try {
            if (Settings.Global.getInt(context.getContentResolver(), KEY, 0) != 1) {
                Settings.Global.putInt(context.getContentResolver(), KEY, 1);
            }
            boolean applied = Settings.Global.getInt(context.getContentResolver(), KEY, 0) == 1;
            if (!applied) {
                Log.e(TAG, "Automatic-update setting did not stay disabled");
            }
            return applied;
        } catch (RuntimeException e) {
            Log.e(TAG, "Cannot enforce automatic-update setting", e);
            return false;
        }
    }
}

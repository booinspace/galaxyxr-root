package boo.puppy.gxr.updatehold;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

public final class BootReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        String action = intent.getAction();
        if (Intent.ACTION_LOCKED_BOOT_COMPLETED.equals(action)
                || Intent.ACTION_BOOT_COMPLETED.equals(action)) {
            if (!UpdateGuard.enforce(context)) {
                Log.w("GxrUpdateHold", "Boot guard unavailable; open app to check permission");
            }
        }
    }
}

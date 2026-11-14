package boo.puppy.gxr.updatehold;

import android.app.Activity;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.os.Build;
import android.os.Bundle;
import android.provider.Settings;
import android.view.View;
import android.widget.Button;
import android.widget.TextView;

import java.io.IOException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public final class MainActivity extends Activity {
    private static final String FOTA = "com.wssyncmldm";
    private static final String SO_AGENT = "com.sec.android.soagent";
    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private TextView title;
    private TextView build;
    private TextView agents;
    private TextView automatic;
    private TextView boot;
    private TextView result;
    private Button hold;
    private Button allow;
    private Button refresh;
    private boolean busy;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        title = findViewById(R.id.statusTitle);
        build = findViewById(R.id.buildText);
        agents = findViewById(R.id.agentText);
        automatic = findViewById(R.id.autoText);
        boot = findViewById(R.id.bootText);
        result = findViewById(R.id.resultText);
        hold = findViewById(R.id.holdButton);
        allow = findViewById(R.id.allowButton);
        refresh = findViewById(R.id.refreshButton);
        hold.setOnClickListener(view -> change(true));
        allow.setOnClickListener(view -> change(false));
        refresh.setOnClickListener(view -> {
            UpdateGuard.enforce(this);
            refreshStatus();
        });
    }

    @Override
    protected void onResume() {
        super.onResume();
        UpdateGuard.enforce(this);
        refreshStatus();
    }

    @Override
    protected void onDestroy() {
        worker.shutdown();
        super.onDestroy();
    }

    private void change(boolean pause) {
        busy = true;
        updateButtons();
        showResult("Waiting for KernelSU permission…", true);
        worker.execute(() -> {
            RootActions.Result action;
            try {
                action = RootActions.apply(pause);
            } catch (IOException | InterruptedException e) {
                action = new RootActions.Result(false, e.getMessage());
                if (e instanceof InterruptedException) {
                    Thread.currentThread().interrupt();
                }
            }
            RootActions.Result completed = action;
            runOnUiThread(() -> {
                if (isDestroyed()) {
                    return;
                }
                busy = false;
                UpdateGuard.enforce(this);
                Status status = refreshStatus();
                boolean expected = pause ? status.held : status.available;
                if (completed.success && expected && status.automaticOff && status.bootReady) {
                    showResult(pause
                            ? "Firmware updates held. The state survives a full reboot."
                            : "Manual update checks are available. Hold again when finished.", true);
                } else {
                    String detail = completed.message == null ? "" : completed.message;
                    if (detail.length() > 320) {
                        detail = detail.substring(detail.length() - 320);
                    }
                    showResult("Could not verify the change. " + detail
                            + "\nIf root is unavailable, run DirtyFrag and grant this app Superuser in KernelSU GXR.", false);
                }
            });
        });
    }

    private Status refreshStatus() {
        boolean supported = "xrvst2".equals(Build.DEVICE);
        int fota = packageState(FOTA);
        int soAgent = packageState(SO_AGENT);
        boolean held = disabled(fota) && disabled(soAgent);
        boolean available = enabled(fota) && enabled(soAgent);
        boolean automaticOff = Settings.Global.getInt(getContentResolver(), UpdateGuard.KEY, 0) == 1;
        boolean bootReady = UpdateGuard.hasPermission(this);

        build.setText("Device: " + Build.MODEL + "  •  Build: " + Build.DISPLAY);
        if (!supported || fota == -1 || soAgent == -1) {
            title.setText("Unsupported device");
            agents.setText("Samsung update agents: Missing on this device");
        } else if (held) {
            title.setText("Updates held");
            agents.setText("Samsung update agents: Both disabled");
        } else if (available) {
            title.setText("Manual checks available");
            agents.setText("Samsung update agents: Both enabled");
        } else {
            title.setText("Mixed update state");
            agents.setText("Samsung update agents: One or both need attention");
        }
        automatic.setText("Automatic scheduling: " + (automaticOff ? "Off" : "On"));
        boot.setText("Boot guard: " + (bootReady ? "Ready" : "Needs one-time permission"));
        updateButtons();
        return new Status(held, available, automaticOff, bootReady);
    }

    private int packageState(String name) {
        PackageManager manager = getPackageManager();
        try {
            manager.getPackageInfo(name, 0);
            return manager.getApplicationEnabledSetting(name);
        } catch (PackageManager.NameNotFoundException | IllegalArgumentException e) {
            return -1;
        }
    }

    private static boolean disabled(int state) {
        return state == PackageManager.COMPONENT_ENABLED_STATE_DISABLED
                || state == PackageManager.COMPONENT_ENABLED_STATE_DISABLED_USER;
    }

    private static boolean enabled(int state) {
        return state == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT
                || state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED;
    }

    private void updateButtons() {
        boolean supported = "xrvst2".equals(Build.DEVICE)
                && packageState(FOTA) != -1 && packageState(SO_AGENT) != -1;
        hold.setEnabled(supported && !busy);
        allow.setEnabled(supported && !busy);
        refresh.setEnabled(!busy);
    }

    private void showResult(String message, boolean success) {
        result.setText(message);
        result.setTextColor(Color.parseColor(success ? "#D7EA85" : "#FFB4AB"));
        result.setVisibility(View.VISIBLE);
    }

    private static final class Status {
        final boolean held;
        final boolean available;
        final boolean automaticOff;
        final boolean bootReady;

        Status(boolean held, boolean available, boolean automaticOff, boolean bootReady) {
            this.held = held;
            this.available = available;
            this.automaticOff = automaticOff;
            this.bootReady = bootReady;
        }
    }
}

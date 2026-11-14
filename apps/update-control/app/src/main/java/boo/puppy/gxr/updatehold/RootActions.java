package boo.puppy.gxr.updatehold;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.TimeUnit;

final class RootActions {
    private static final String APP = "boo.puppy.gxr.updatehold";
    private static final String FOTA = "com.wssyncmldm";
    private static final String SO_AGENT = "com.sec.android.soagent";

    private RootActions() {}

    static Result apply(boolean hold) throws IOException, InterruptedException {
        String verb = hold ? "disable-user" : "default-state";
        String script = "set -eu\n"
                + "test \"$(id -u)\" = 0\n"
                + "pm grant " + APP + " android.permission.WRITE_SECURE_SETTINGS\n"
                + "settings put global " + UpdateGuard.KEY + " 1\n"
                + "pm " + verb + " --user 0 " + FOTA + "\n"
                + "pm " + verb + " --user 0 " + SO_AGENT + "\n"
                + "test \"$(settings get global " + UpdateGuard.KEY + ")\" = 1\n";

        Process process = new ProcessBuilder("su", "-c", script)
                .redirectErrorStream(true)
                .start();
        if (!process.waitFor(120, TimeUnit.SECONDS)) {
            process.destroyForcibly();
            return new Result(false, "KernelSU did not answer within two minutes.");
        }
        String output = new String(process.getInputStream().readAllBytes(), StandardCharsets.UTF_8).trim();
        return new Result(process.exitValue() == 0, output);
    }

    static final class Result {
        final boolean success;
        final String message;

        Result(boolean success, String message) {
            this.success = success;
            this.message = message;
        }
    }
}

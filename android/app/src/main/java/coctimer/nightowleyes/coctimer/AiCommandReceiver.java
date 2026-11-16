package coctimer.nightowleyes.coctimer;

import android.app.Activity;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Handler;
import android.os.Looper;
import android.util.Base64;
import android.util.Log;

import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicBoolean;

import io.flutter.FlutterInjector;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.dart.DartExecutor;
import io.flutter.embedding.engine.loader.FlutterLoader;
import io.flutter.plugin.common.MethodChannel;

public class AiCommandReceiver extends BroadcastReceiver {

    public static final String ACTION_IMPORT_JSON = "coctimer.ACTION_IMPORT_JSON";
    public static final String ACTION_QUERY_UPGRADES = "coctimer.ACTION_QUERY_UPGRADES";
    public static final String CHANNEL_NAME = "coctimer/ai_command";
    public static final String LOG_TAG = "COCTIMER_AI";
    public static final String DEFAULT_RESULT_FILE = "coctimer_result.json";

    private static final ExecutorService IO_EXECUTOR = Executors.newSingleThreadExecutor();
    private static final long COMMAND_TIMEOUT_MS = 8500L;

    public static class ParsedIntentCommand {
        public final String method;
        public final Map<String, Object> args;
        public final String outputPath;
        public final String errorJson;

        ParsedIntentCommand(String method, Map<String, Object> args, String outputPath, String errorJson) {
            this.method = method;
            this.args = args;
            this.outputPath = outputPath;
            this.errorJson = errorJson;
        }
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null || intent.getAction() == null) {
            return;
        }
        final String action = intent.getAction();
        if (!ACTION_IMPORT_JSON.equals(action) && !ACTION_QUERY_UPGRADES.equals(action)) {
            return;
        }

        final Context appContext = context.getApplicationContext();
        final PendingResult pendingResult = goAsync();
        final AtomicBoolean finished = new AtomicBoolean(false);
        final Handler mainHandler = new Handler(Looper.getMainLooper());

        final Intent safeIntent = new Intent(intent);

        IO_EXECUTOR.execute(() -> {
            final ParsedIntentCommand parsed = parseIntent(appContext, safeIntent);
            if (parsed.errorJson != null) {
                deliverOutput(appContext, parsed.outputPath, parsed.errorJson, pendingResult, finished);
                return;
            }

            mainHandler.post(() -> executeOnMainThread(appContext, parsed, pendingResult, finished, mainHandler));
        });
    }

    private void executeOnMainThread(
            Context appContext,
            ParsedIntentCommand parsed,
            PendingResult pendingResult,
            AtomicBoolean finished,
            Handler mainHandler
    ) {
        if (MainActivity.isAiChannelReady()) {
            final Runnable timeoutTask = () -> {
                String err = buildErrorJson(parsed.method, "Timed out waiting for active Flutter engine.");
                deliverOutput(appContext, parsed.outputPath, err, pendingResult, finished);
            };
            mainHandler.postDelayed(timeoutTask, COMMAND_TIMEOUT_MS);

            MainActivity.dispatchAiCommand(parsed.method, parsed.args, jsonResult -> {
                mainHandler.removeCallbacks(timeoutTask);
                deliverOutput(appContext, parsed.outputPath, jsonResult, pendingResult, finished);
            });
            return;
        }

        final FlutterEngine[] bgEngineHolder = new FlutterEngine[1];
        final Runnable timeoutTask = () -> {
            String err = buildErrorJson(parsed.method, "Timed out running headless Flutter engine.");
            deliverOutput(appContext, parsed.outputPath, err, pendingResult, finished);
            destroyEngineSafely(bgEngineHolder[0], mainHandler);
        };
        mainHandler.postDelayed(timeoutTask, COMMAND_TIMEOUT_MS);

        try {
            FlutterLoader loader = FlutterInjector.instance().flutterLoader();
            if (!loader.initialized()) {
                loader.startInitialization(appContext);
            }
            loader.ensureInitializationComplete(appContext, null);

            FlutterEngine bgEngine = new FlutterEngine(appContext);
            bgEngineHolder[0] = bgEngine;

            MethodChannel bgChannel = new MethodChannel(
                    bgEngine.getDartExecutor().getBinaryMessenger(),
                    CHANNEL_NAME
            );
            bgChannel.setMethodCallHandler((call, result) -> {
                if ("aiReady".equals(call.method)) {
                    result.success(null);
                    bgChannel.invokeMethod(parsed.method, parsed.args, new MethodChannel.Result() {
                        @Override
                        public void success(Object res) {
                            mainHandler.removeCallbacks(timeoutTask);
                            String out = res != null
                                    ? res.toString()
                                    : buildErrorJson(parsed.method, "Empty response from Dart.");
                            deliverOutput(appContext, parsed.outputPath, out, pendingResult, finished);
                            destroyEngineSafely(bgEngine, mainHandler);
                        }

                        @Override
                        public void error(String code, String msg, Object details) {
                            mainHandler.removeCallbacks(timeoutTask);
                            String err = buildErrorJson(parsed.method, code + ": " + msg);
                            deliverOutput(appContext, parsed.outputPath, err, pendingResult, finished);
                            destroyEngineSafely(bgEngine, mainHandler);
                        }

                        @Override
                        public void notImplemented() {
                            mainHandler.removeCallbacks(timeoutTask);
                            String err = buildErrorJson(parsed.method, "AI method not implemented.");
                            deliverOutput(appContext, parsed.outputPath, err, pendingResult, finished);
                            destroyEngineSafely(bgEngine, mainHandler);
                        }
                    });
                } else {
                    result.notImplemented();
                }
            });

            bgEngine.getDartExecutor().executeDartEntrypoint(
                    new DartExecutor.DartEntrypoint(
                            loader.findAppBundlePath(),
                            "aiCommandEntrypoint"
                    )
            );
        } catch (Exception e) {
            mainHandler.removeCallbacks(timeoutTask);
            String err = buildErrorJson(parsed.method, "Failed to start headless FlutterEngine: " + e.getMessage());
            deliverOutput(appContext, parsed.outputPath, err, pendingResult, finished);
            destroyEngineSafely(bgEngineHolder[0], mainHandler);
        }
    }

    private static void destroyEngineSafely(FlutterEngine engine, Handler mainHandler) {
        if (engine == null) return;
        mainHandler.postDelayed(() -> {
            try {
                engine.destroy();
            } catch (Exception ignored) {}
        }, 200);
    }

    public static ParsedIntentCommand parseIntent(Context appContext, Intent intent) {
        String action = intent.getAction();
        String method = ACTION_QUERY_UPGRADES.equals(action) ? "queryUpgrades" : "importJson";
        String outputPath = intent.getStringExtra("output");
        if (outputPath == null || outputPath.trim().isEmpty()) {
            outputPath = intent.getStringExtra("output_file");
        }

        Map<String, Object> args = new HashMap<>();
        String name = intent.getStringExtra("name");
        if (name != null && !name.trim().isEmpty()) {
            args.put("name", name.trim());
        }
        String tag = intent.getStringExtra("tag");
        if (tag != null && !tag.trim().isEmpty()) {
            args.put("tag", tag.trim());
        }

        boolean syncAlarms = true;
        if (intent.hasExtra("sync_alarms")) {
            Object rawSync = intent.getExtras() != null ? intent.getExtras().get("sync_alarms") : null;
            if (rawSync instanceof Boolean) {
                syncAlarms = (Boolean) rawSync;
            } else if (rawSync != null) {
                syncAlarms = !"false".equalsIgnoreCase(rawSync.toString().trim());
            }
        }
        args.put("sync_alarms", syncAlarms);

        if ("importJson".equals(method)) {
            String json = intent.getStringExtra("json");
            if (json == null || json.trim().isEmpty()) {
                String b64 = intent.getStringExtra("base64");
                if (b64 != null && !b64.trim().isEmpty()) {
                    try {
                        byte[] decoded = Base64.decode(b64.trim(), Base64.DEFAULT);
                        json = new String(decoded, StandardCharsets.UTF_8);
                    } catch (Exception e) {
                        return new ParsedIntentCommand(method, args, outputPath,
                                buildErrorJson("import_json", "Invalid base64 payload: " + e.getMessage()));
                    }
                }
            }

            if (json == null || json.trim().isEmpty()) {
                String filePath = intent.getStringExtra("file");
                if (filePath == null || filePath.trim().isEmpty()) {
                    filePath = intent.getStringExtra("json_file");
                }
                if (filePath != null && !filePath.trim().isEmpty()) {
                    try {
                        json = readTextFile(appContext, filePath.trim());
                    } catch (Exception e) {
                        File extDir = appContext.getExternalFilesDir(null);
                        String hintDir = extDir != null ? extDir.getAbsolutePath() : "/sdcard/Android/data/coctimer.nightowleyes.coctimer/files";
                        return new ParsedIntentCommand(method, args, outputPath,
                                buildErrorJson("import_json",
                                        "Cannot read file '" + filePath + "': " + e.getMessage()
                                                + ". Tip: push file to '" + hintDir + "' or pass --es base64 / --es json."));
                    }
                }
            }

            if (json == null || json.trim().isEmpty()) {
                return new ParsedIntentCommand(method, args, outputPath,
                        buildErrorJson("import_json", "Missing input. Provide --es file, --es base64, or --es json."));
            }
            args.put("json", json);
        }

        return new ParsedIntentCommand(method, args, outputPath, null);
    }

    private static String readTextFile(Context appContext, String rawPath) throws Exception {
        File file = new File(rawPath);
        if (!file.isAbsolute()) {
            File extDir = appContext.getExternalFilesDir(null);
            if (extDir != null) {
                file = new File(extDir, rawPath);
            }
        }
        try (FileInputStream fis = new FileInputStream(file);
             ByteArrayOutputStream bos = new ByteArrayOutputStream()) {
            byte[] buffer = new byte[8192];
            int len;
            while ((len = fis.read(buffer)) != -1) {
                bos.write(buffer, 0, len);
            }
            return bos.toString(StandardCharsets.UTF_8.name());
        }
    }

    public static void deliverOutput(
            Context appContext,
            String customOutputPath,
            String jsonResult,
            PendingResult pendingResult,
            AtomicBoolean finished
    ) {
        if (finished != null && !finished.compareAndSet(false, true)) {
            return;
        }

        String finalJson = jsonResult != null ? jsonResult : buildErrorJson("unknown", "Null result");
        File defaultFile = writeDefaultResultFile(appContext, finalJson);
        if (defaultFile != null) {
            try {
                JSONObject obj = new JSONObject(finalJson);
                obj.put("result_file", defaultFile.getAbsolutePath());
                finalJson = obj.toString();
                writeFileBytes(defaultFile, finalJson);
            } catch (Exception ignored) {}
        }

        if (customOutputPath != null && !customOutputPath.trim().isEmpty()) {
            try {
                File customFile = new File(customOutputPath.trim());
                if (!customFile.isAbsolute()) {
                    File extDir = appContext.getExternalFilesDir(null);
                    if (extDir != null) customFile = new File(extDir, customOutputPath.trim());
                }
                writeFileBytes(customFile, finalJson);
            } catch (Exception e) {
                Log.w(LOG_TAG, "Could not write custom output file '" + customOutputPath + "': " + e.getMessage());
            }
        }

        Log.i(LOG_TAG, finalJson);

        if (pendingResult != null) {
            try {
                pendingResult.setResultCode(Activity.RESULT_OK);
                pendingResult.setResultData(finalJson);
            } finally {
                pendingResult.finish();
            }
        }
    }

    private static File writeDefaultResultFile(Context appContext, String content) {
        try {
            File extDir = appContext.getExternalFilesDir(null);
            if (extDir == null) {
                extDir = appContext.getFilesDir();
            }
            if (!extDir.exists()) {
                extDir.mkdirs();
            }
            File outFile = new File(extDir, DEFAULT_RESULT_FILE);
            writeFileBytes(outFile, content);
            return outFile;
        } catch (Exception e) {
            Log.w(LOG_TAG, "Failed writing default result file: " + e.getMessage());
            return null;
        }
    }

    private static void writeFileBytes(File target, String content) throws Exception {
        File parent = target.getParentFile();
        if (parent != null && !parent.exists()) {
            parent.mkdirs();
        }
        try (FileOutputStream fos = new FileOutputStream(target, false)) {
            fos.write(content.getBytes(StandardCharsets.UTF_8));
            fos.flush();
        }
    }

    public static String buildErrorJson(String action, String errorMessage) {
        try {
            return new JSONObject()
                    .put("success", false)
                    .put("action", action)
                    .put("error", errorMessage)
                    .toString();
        } catch (Exception e) {
            return "{\"success\":false,\"error\":\"Failed to serialize error\"}";
        }
    }
}

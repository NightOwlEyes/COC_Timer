package coctimer.nightowleyes.coctimer;

import android.app.NotificationManager;
import android.app.KeyguardManager;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.PowerManager;
import android.provider.Settings;
import android.view.WindowManager;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {

    private static final String CHANNEL = "coctimer/fsi_permission";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        // Đã dọn dẹp sạch cờ khởi động
        super.onCreate(savedInstanceState);
    }

    @Override
    public void onAttachedToWindow() {
        super.onAttachedToWindow();
        // Đã dọn dẹp sạch cờ khởi động
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    switch (call.method) {
                        case "canUseFullScreenIntent":
                            result.success(canUseFullScreenIntent());
                            break;
                        case "openFullScreenIntentSettings":
                            openFullScreenIntentSettings();
                            result.success(null);
                            break;
                        case "isIgnoringBatteryOptimizations":
                            result.success(isIgnoringBatteryOptimizations());
                            break;
                        case "requestIgnoreBatteryOptimizations":
                            requestIgnoreBatteryOptimizations();
                            result.success(null);
                            break;
                        case "handleAlarmDismiss":
                            handleAlarmDismiss();
                            result.success(null);
                            break;
                        case "enableAlarmMode":
                            enableAlarmMode();
                            result.success(null);
                            break;
                        case "disableAlarmMode":
                            disableAlarmMode();
                            result.success(null);
                            break;
                        case "allowScreenTimeout":
                            allowScreenTimeout();
                            result.success(null);
                            break;
                        default:
                            result.notImplemented();
                    }
                });
    }

    private boolean isIgnoringBatteryOptimizations() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PowerManager pm = (PowerManager) getSystemService(POWER_SERVICE);
            return pm != null && pm.isIgnoringBatteryOptimizations(getPackageName());
        }
        return true;
    }

    private void requestIgnoreBatteryOptimizations() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                Intent intent = new Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS);
                intent.setData(Uri.parse("package:" + getPackageName()));
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                startActivity(intent);
            } catch (Exception e) {
                try {
                    Intent intent2 = new Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS);
                    intent2.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    startActivity(intent2);
                } catch (Exception ignored) {}
            }
        }
    }

    private void handleAlarmDismiss() {
        KeyguardManager km = (KeyguardManager) getSystemService(Context.KEYGUARD_SERVICE);
        if (km != null && km.isKeyguardLocked()) {
            moveTaskToBack(true);
        }
    }

    private boolean canUseFullScreenIntent() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            NotificationManager nm = getSystemService(NotificationManager.class);
            return nm != null && nm.canUseFullScreenIntent();
        }
        return true;
    }

    private void openFullScreenIntentSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            Intent intent = new Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT);
            intent.setData(Uri.parse("package:" + getPackageName()));
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            startActivity(intent);
        }
    }

    private void enableAlarmMode() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true);
            setTurnScreenOn(true);
        }
        getWindow().addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED |
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON |
                        WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON |
                        WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON
        );
    }

    private void disableAlarmMode() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(false);
            setTurnScreenOn(false);
        }
        getWindow().clearFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED |
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON |
                        WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON |
                        WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON
        );
    }

    private void allowScreenTimeout() {
        getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
    }
}
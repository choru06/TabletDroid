package com.tabletdroid.benchmark;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

public class BenchmarkReceiver extends BroadcastReceiver {
    public static final String ACTION_START = "com.tabletdroid.benchmark.ACTION_START";
    public static final String ACTION_STOP = "com.tabletdroid.benchmark.ACTION_STOP";
    public static final String ACTION_RESET = "com.tabletdroid.benchmark.ACTION_RESET";
    public static final String ACTION_GET_STATUS = "com.tabletdroid.benchmark.ACTION_GET_STATUS";

    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null || intent.getAction() == null) return;
        String action = intent.getAction();
        Log.i(BenchmarkState.TAG, "Received broadcast action: " + action);

        if (ACTION_START.equals(action)) {
            int warmupSec = intent.getIntExtra("warmup_sec", 10);
            int measureSec = intent.getIntExtra("measure_sec", 30);
            double velocity = intent.getDoubleExtra("velocity_px_s", 800.0);
            if (velocity <= 0) velocity = 800.0;

            if (BenchmarkState.listener != null) {
                BenchmarkState.listener.onStartCommand(warmupSec, measureSec, velocity);
            } else {
                Log.w(BenchmarkState.TAG, "No active activity listener to start benchmark. Launching activity...");
                Intent launch = new Intent(context, BenchmarkActivity.class);
                launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP);
                launch.putExtra("autostart", true);
                launch.putExtra("warmup_sec", warmupSec);
                launch.putExtra("measure_sec", measureSec);
                launch.putExtra("velocity_px_s", velocity);
                context.startActivity(launch);
            }
        } else if (ACTION_STOP.equals(action)) {
            if (BenchmarkState.listener != null) {
                BenchmarkState.listener.onStopCommand();
            }
        } else if (ACTION_RESET.equals(action)) {
            if (BenchmarkState.listener != null) {
                BenchmarkState.listener.onResetCommand();
            }
        } else if (ACTION_GET_STATUS.equals(action)) {
            if (BenchmarkState.listener != null) {
                BenchmarkState.listener.onGetStatusCommand();
            } else {
                logCurrentStatus();
            }
        }
    }

    private void logCurrentStatus() {
        long elapsedMs = 0;
        if (BenchmarkState.currentStatus == BenchmarkState.Status.RUNNING && BenchmarkState.measureStartMs > 0) {
            elapsedMs = System.currentTimeMillis() - BenchmarkState.measureStartMs;
        } else if (BenchmarkState.currentStatus == BenchmarkState.Status.COMPLETE && BenchmarkState.measureEndMs > BenchmarkState.measureStartMs) {
            elapsedMs = BenchmarkState.measureEndMs - BenchmarkState.measureStartMs;
        }

        String json = String.format(
            "{\"status\":\"%s\",\"workloadVersion\":\"%s\",\"requestedVelocity\":%.1f,\"actualDistance\":%.1f,\"warmupSec\":%d,\"measureSec\":%d,\"elapsedMeasureMs\":%d,\"measureFrames\":%d}",
            BenchmarkState.currentStatus.name(),
            BenchmarkState.WORKLOAD_VERSION,
            BenchmarkState.requestedVelocityPxPerSec,
            BenchmarkState.actualScrollDistancePx,
            BenchmarkState.warmupDurationSec,
            BenchmarkState.measureDurationSec,
            elapsedMs,
            BenchmarkState.measureFramesRendered
        );
        Log.i(BenchmarkState.TAG, "BENCHMARK_STATUS_JSON: " + json);
    }
}

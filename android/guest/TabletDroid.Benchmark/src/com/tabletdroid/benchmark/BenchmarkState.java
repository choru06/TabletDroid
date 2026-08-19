package com.tabletdroid.benchmark;

public class BenchmarkState {
    public enum Status {
        IDLE,
        WARMUP,
        RUNNING,
        COMPLETE
    }

    public static final String WORKLOAD_VERSION = "1.0.0";
    public static final String TAG = "TabletDroidBenchmark";

    public static volatile Status currentStatus = Status.IDLE;
    public static volatile double requestedVelocityPxPerSec = 800.0;
    public static volatile double actualScrollDistancePx = 0.0;
    public static volatile int warmupDurationSec = 10;
    public static volatile int measureDurationSec = 30;
    public static volatile long warmupStartMs = 0;
    public static volatile long measureStartMs = 0;
    public static volatile long measureEndMs = 0;
    public static volatile long totalFramesRendered = 0;
    public static volatile long measureFramesRendered = 0;

    public interface StateListener {
        void onStartCommand(int warmupSec, int measureSec, double velocity);
        void onStopCommand();
        void onResetCommand();
    }

    public static volatile StateListener listener = null;
}

package com.tabletdroid.benchmark;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.DisplayMetrics;
import android.util.Log;
import android.view.Choreographer;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

public class BenchmarkActivity extends Activity implements BenchmarkState.StateListener {
    private ScrollView scrollView;
    private LinearLayout cardsContainer;
    private TextView tvStatus;
    private TextView tvSpeed;
    private TextView tvDistance;
    private TextView tvElapsed;
    private TextView tvResolution;

    private Handler mainHandler;
    private boolean isAutoScrolling = false;
    private int scrollDirection = 1; // 1 = down, -1 = up
    private double accumulatedSubPixelY = 0.0;
    private long lastFrameNanos = 0;

    private static final int CARD_COUNT = 100;

    private final Choreographer.FrameCallback frameCallback = new Choreographer.FrameCallback() {
        @Override
        public void doFrame(long frameTimeNanos) {
            if (!isAutoScrolling) return;

            if (lastFrameNanos > 0) {
                double dt = (frameTimeNanos - lastFrameNanos) / 1_000_000_000.0;
                // Clamp dt to avoid huge jumps on frame drops (e.g. max 0.1s)
                if (dt > 0.1) dt = 0.1;

                double deltaY = BenchmarkState.requestedVelocityPxPerSec * dt * scrollDirection;
                accumulatedSubPixelY += deltaY;

                int intDelta = (int) accumulatedSubPixelY;
                if (intDelta != 0) {
                    accumulatedSubPixelY -= intDelta;

                    int oldScrollY = scrollView.getScrollY();
                    scrollView.scrollBy(0, intDelta);
                    int actualMoved = scrollView.getScrollY() - oldScrollY;

                    // Boundary checks
                    int maxScroll = cardsContainer.getHeight() - scrollView.getHeight();
                    if (scrollView.getScrollY() >= maxScroll && scrollDirection > 0) {
                        scrollDirection = -1;
                    } else if (scrollView.getScrollY() <= 0 && scrollDirection < 0) {
                        scrollDirection = 1;
                    }

                    if (BenchmarkState.currentStatus == BenchmarkState.Status.RUNNING) {
                        BenchmarkState.actualScrollDistancePx += Math.abs(actualMoved);
                    }
                }

                BenchmarkState.totalFramesRendered++;
                if (BenchmarkState.currentStatus == BenchmarkState.Status.RUNNING) {
                    BenchmarkState.measureFramesRendered++;
                }

                updateUiProgress();
            }

            lastFrameNanos = frameTimeNanos;
            Choreographer.getInstance().postFrameCallback(this);
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_benchmark);

        mainHandler = new Handler(Looper.getMainLooper());

        scrollView = findViewById(R.id.benchmark_scroll_view);
        cardsContainer = findViewById(R.id.cards_container);
        tvStatus = findViewById(R.id.tv_status);
        tvSpeed = findViewById(R.id.tv_speed);
        tvDistance = findViewById(R.id.tv_distance);
        tvElapsed = findViewById(R.id.tv_elapsed);
        tvResolution = findViewById(R.id.tv_resolution);

        DisplayMetrics dm = getResources().getDisplayMetrics();
        tvResolution.setText(String.format("%dx%d @ %ddpi", dm.widthPixels, dm.heightPixels, dm.densityDpi));

        populateDeterministicCards();

        BenchmarkState.listener = this;
        Log.i(BenchmarkState.TAG, "BenchmarkActivity created and listener registered.");

        handleIntent(getIntent());
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        handleIntent(intent);
    }

    private void handleIntent(Intent intent) {
        if (intent != null && intent.getBooleanExtra("autostart", false)) {
            int warmupSec = intent.getIntExtra("warmup_sec", 10);
            int measureSec = intent.getIntExtra("measure_sec", 30);
            double velocity = intent.getDoubleExtra("velocity_px_s", 800.0);
            onStartCommand(warmupSec, measureSec, velocity);
        }
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        stopAutoScroll();
        if (BenchmarkState.listener == this) {
            BenchmarkState.listener = null;
        }
    }

    private void populateDeterministicCards() {
        LayoutInflater inflater = LayoutInflater.from(this);
        cardsContainer.removeAllViews();

        int[] avatarColors = {
            Color.parseColor("#3B82F6"), // Blue
            Color.parseColor("#6366F1"), // Indigo
            Color.parseColor("#10B981"), // Emerald
            Color.parseColor("#F59E0B"), // Amber
            Color.parseColor("#F43F5E")  // Rose
        };

        for (int i = 1; i <= CARD_COUNT; i++) {
            View card = inflater.inflate(R.layout.item_card, cardsContainer, false);
            TextView tvTitle = card.findViewById(R.id.card_title);
            TextView tvSubtitle = card.findViewById(R.id.card_subtitle);
            TextView tvBadge = card.findViewById(R.id.card_badge);
            TextView tvBody = card.findViewById(R.id.card_body);
            View avatar = card.findViewById(R.id.card_avatar);

            tvTitle.setText(String.format("Deterministic Workload Item #%03d", i));
            tvSubtitle.setText(String.format("Memory Hash: 0x%08X | Batch: %d", (i * 31337), (i / 10) + 1));
            tvBadge.setText(String.format("CARD #%02d", i));

            GradientDrawable avatarBg = new GradientDrawable();
            avatarBg.setShape(GradientDrawable.OVAL);
            avatarBg.setColor(avatarColors[(i - 1) % avatarColors.length]);
            avatar.setBackground(avatarBg);

            cardsContainer.addView(card);
        }
        Log.i(BenchmarkState.TAG, String.format("Populated %d deterministic cards into container.", CARD_COUNT));
    }

    @Override
    public void onStartCommand(final int warmupSec, final int measureSec, final double velocity) {
        mainHandler.post(new Runnable() {
            @Override
            public void run() {
                startBenchmarkSequence(warmupSec, measureSec, velocity);
            }
        });
    }

    @Override
    public void onStopCommand() {
        mainHandler.post(new Runnable() {
            @Override
            public void run() {
                stopAutoScroll();
                BenchmarkState.currentStatus = BenchmarkState.Status.IDLE;
                tvStatus.setText("STATUS: STOPPED");
                tvStatus.setTextColor(Color.parseColor("#F43F5E"));
                emitStatusJson();
            }
        });
    }

    @Override
    public void onResetCommand() {
        mainHandler.post(new Runnable() {
            @Override
            public void run() {
                stopAutoScroll();
                scrollView.scrollTo(0, 0);
                scrollDirection = 1;
                accumulatedSubPixelY = 0.0;
                BenchmarkState.currentStatus = BenchmarkState.Status.IDLE;
                BenchmarkState.actualScrollDistancePx = 0.0;
                BenchmarkState.totalFramesRendered = 0;
                BenchmarkState.measureFramesRendered = 0;
                BenchmarkState.warmupStartMs = 0;
                BenchmarkState.measureStartMs = 0;
                BenchmarkState.measureEndMs = 0;

                tvStatus.setText("STATUS: IDLE");
                tvStatus.setTextColor(Color.parseColor("#3B82F6"));
                tvDistance.setText("Distance: 0 px");
                tvElapsed.setText("Elapsed: 0.0s");
                emitStatusJson();
            }
        });
    }

    private void startBenchmarkSequence(int warmupSec, int measureSec, double velocity) {
        stopAutoScroll();
        scrollView.scrollTo(0, 0);
        scrollDirection = 1;
        accumulatedSubPixelY = 0.0;

        BenchmarkState.requestedVelocityPxPerSec = velocity;
        BenchmarkState.warmupDurationSec = warmupSec;
        BenchmarkState.measureDurationSec = measureSec;
        BenchmarkState.actualScrollDistancePx = 0.0;
        BenchmarkState.totalFramesRendered = 0;
        BenchmarkState.measureFramesRendered = 0;

        tvSpeed.setText(String.format("Velocity: %.0f px/s", velocity));

        // Start Warmup Phase
        BenchmarkState.currentStatus = BenchmarkState.Status.WARMUP;
        BenchmarkState.warmupStartMs = System.currentTimeMillis();
        tvStatus.setText("STATUS: WARMUP (" + warmupSec + "s)");
        tvStatus.setTextColor(Color.parseColor("#F59E0B"));
        Log.i(BenchmarkState.TAG, String.format("Starting WARMUP phase (%ds at %.1f px/s)", warmupSec, velocity));
        emitStatusJson();

        startAutoScroll();

        // Schedule Measurement Phase
        mainHandler.postDelayed(new Runnable() {
            @Override
            public void run() {
                if (BenchmarkState.currentStatus != BenchmarkState.Status.WARMUP) return;

                BenchmarkState.currentStatus = BenchmarkState.Status.RUNNING;
                BenchmarkState.measureStartMs = System.currentTimeMillis();
                BenchmarkState.actualScrollDistancePx = 0.0;
                BenchmarkState.measureFramesRendered = 0;

                tvStatus.setText("STATUS: MEASURING (" + BenchmarkState.measureDurationSec + "s)");
                tvStatus.setTextColor(Color.parseColor("#10B981"));
                Log.i(BenchmarkState.TAG, String.format("Starting MEASUREMENT phase (%ds)", BenchmarkState.measureDurationSec));
                emitStatusJson();

                // Schedule Completion Phase
                mainHandler.postDelayed(new Runnable() {
                    @Override
                    public void run() {
                        if (BenchmarkState.currentStatus != BenchmarkState.Status.RUNNING) return;

                        BenchmarkState.measureEndMs = System.currentTimeMillis();
                        BenchmarkState.currentStatus = BenchmarkState.Status.COMPLETE;
                        stopAutoScroll();

                        tvStatus.setText("STATUS: COMPLETE");
                        tvStatus.setTextColor(Color.parseColor("#3B82F6"));
                        Log.i(BenchmarkState.TAG, "MEASUREMENT phase COMPLETE!");
                        emitStatusJson();
                    }
                }, BenchmarkState.measureDurationSec * 1000L);

            }
        }, warmupSec * 1000L);
    }

    private void startAutoScroll() {
        if (!isAutoScrolling) {
            isAutoScrolling = true;
            lastFrameNanos = 0;
            Choreographer.getInstance().postFrameCallback(frameCallback);
        }
    }

    private void stopAutoScroll() {
        isAutoScrolling = false;
        Choreographer.getInstance().removeFrameCallback(frameCallback);
    }

    private void updateUiProgress() {
        long elapsedMs = 0;
        if (BenchmarkState.currentStatus == BenchmarkState.Status.WARMUP && BenchmarkState.warmupStartMs > 0) {
            elapsedMs = System.currentTimeMillis() - BenchmarkState.warmupStartMs;
        } else if (BenchmarkState.currentStatus == BenchmarkState.Status.RUNNING && BenchmarkState.measureStartMs > 0) {
            elapsedMs = System.currentTimeMillis() - BenchmarkState.measureStartMs;
        } else if (BenchmarkState.currentStatus == BenchmarkState.Status.COMPLETE && BenchmarkState.measureEndMs > BenchmarkState.measureStartMs) {
            elapsedMs = BenchmarkState.measureEndMs - BenchmarkState.measureStartMs;
        }

        tvDistance.setText(String.format("Distance: %.0f px", BenchmarkState.actualScrollDistancePx));
        tvElapsed.setText(String.format("Elapsed: %.1fs", elapsedMs / 1000.0));
    }

    private void emitStatusJson() {
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

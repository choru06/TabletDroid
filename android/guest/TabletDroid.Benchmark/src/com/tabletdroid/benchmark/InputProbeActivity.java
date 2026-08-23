package com.tabletdroid.benchmark;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.os.Bundle;
import android.os.SystemClock;
import android.util.Log;
import android.view.Choreographer;
import android.view.MotionEvent;
import android.view.View;
import android.widget.FrameLayout;
import android.widget.TextView;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.atomic.AtomicInteger;

public class InputProbeActivity extends Activity {
    public static final String TAG = "TabletDroidInputProbe";
    public static final int SCHEMA_VERSION = 2;

    private static final AtomicInteger sequenceCounter = new AtomicInteger(0);
    private static final AtomicInteger gestureCounter = new AtomicInteger(0);

    private ProbeTouchView touchView;
    private TextView tvStats;
    private boolean isCanonicalMode = true;

    private static class EventRecord {
        final int schemaVersion = SCHEMA_VERSION;
        final int sequenceId;
        final int gestureId;
        final String action;
        final int actionCode;
        final long eventUptime;
        final long receiveUptime;
        final long receiveNano;
        final float x;
        final float y;
        long choreographerFrameNano = 0;
        long drawNano = 0;
        double eventToDispatchMs = 0.0;
        double dispatchToFrameMs = 0.0;
        double frameToDrawMs = 0.0;
        double eventToDrawMs = 0.0;

        EventRecord(int sequenceId, int gestureId, String action, int actionCode,
                    long eventUptime, long receiveUptime, long receiveNano, float x, float y) {
            this.sequenceId = sequenceId;
            this.gestureId = gestureId;
            this.action = action;
            this.actionCode = actionCode;
            this.eventUptime = eventUptime;
            this.receiveUptime = receiveUptime;
            this.receiveNano = receiveNano;
            this.x = x;
            this.y = y;

            if (eventUptime > 0 && receiveUptime >= eventUptime) {
                this.eventToDispatchMs = (double) (receiveUptime - eventUptime);
            } else {
                this.eventToDispatchMs = 0.0;
            }
        }
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        parseMode(getIntent());

        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(Color.parseColor("#0F172A")); // Slate 900

        touchView = new ProbeTouchView(this);
        root.addView(touchView, new FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        ));

        tvStats = new TextView(this);
        tvStats.setTextColor(Color.parseColor("#38BDF8")); // Sky 400
        tvStats.setTextSize(16);
        tvStats.setPadding(32, 48, 32, 32);
        tvStats.setText("Input Latency Diagnostic Probe Active\nTap or drag to measure latency.");
        root.addView(tvStats);

        if (isCanonicalMode) {
            tvStats.setVisibility(View.GONE);
        } else {
            tvStats.setVisibility(View.VISIBLE);
        }

        setContentView(root);
        Log.i(TAG, String.format("InputProbeActivity created (CanonicalMode=%b, SchemaVersion=%d).", isCanonicalMode, SCHEMA_VERSION));
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        parseMode(intent);
        if (tvStats != null) {
            tvStats.setVisibility(isCanonicalMode ? View.GONE : View.VISIBLE);
        }
        Log.i(TAG, String.format("InputProbeActivity updated mode (CanonicalMode=%b).", isCanonicalMode));
    }

    private void parseMode(Intent intent) {
        if (intent == null) return;
        if (intent.hasExtra("canonical_mode")) {
            isCanonicalMode = intent.getBooleanExtra("canonical_mode", true);
        } else if (intent.hasExtra("diagnostic_mode")) {
            isCanonicalMode = !intent.getBooleanExtra("diagnostic_mode", false);
        }
    }

    private class ProbeTouchView extends View {
        private final Paint paint = new Paint();
        private float lastX = -100;
        private float lastY = -100;
        private boolean isTouching = false;

        private final List<EventRecord> pendingEvents = new ArrayList<>();
        private long lastChoreographerFrameNano = 0;
        private boolean isFrameCallbackScheduled = false;

        private final Choreographer.FrameCallback frameCallback = new Choreographer.FrameCallback() {
            @Override
            public void doFrame(long frameTimeNano) {
                lastChoreographerFrameNano = frameTimeNano;
                isFrameCallbackScheduled = false;
                for (EventRecord r : pendingEvents) {
                    if (r.choreographerFrameNano == 0) {
                        r.choreographerFrameNano = frameTimeNano;
                    }
                }
            }
        };

        public ProbeTouchView(Context context) {
            super(context);
            paint.setAntiAlias(true);
            paint.setColor(Color.parseColor("#10B981")); // Emerald 500
            paint.setStyle(Paint.Style.FILL);
        }

        @Override
        public boolean onTouchEvent(MotionEvent event) {
            final int actionMasked = event.getActionMasked();
            final String actionName;
            switch (actionMasked) {
                case MotionEvent.ACTION_DOWN:
                    actionName = "DOWN";
                    gestureCounter.incrementAndGet();
                    break;
                case MotionEvent.ACTION_MOVE:
                    actionName = "MOVE";
                    break;
                case MotionEvent.ACTION_UP:
                    actionName = "UP";
                    break;
                case MotionEvent.ACTION_CANCEL:
                    actionName = "CANCEL";
                    break;
                default:
                    actionName = "OTHER_" + actionMasked;
                    break;
            }

            final int seq = sequenceCounter.incrementAndGet();
            final int gestId = gestureCounter.get();
            final long recvUptimeMs = SystemClock.uptimeMillis();
            final long eventUptimeMs = event.getEventTime();
            final long recvNano = System.nanoTime();

            lastX = event.getX();
            lastY = event.getY();
            isTouching = (actionMasked != MotionEvent.ACTION_UP && actionMasked != MotionEvent.ACTION_CANCEL);

            EventRecord record = new EventRecord(
                seq, gestId, actionName, actionMasked,
                eventUptimeMs, recvUptimeMs, recvNano, lastX, lastY
            );

            pendingEvents.add(record);

            if (!isFrameCallbackScheduled) {
                isFrameCallbackScheduled = true;
                Choreographer.getInstance().postFrameCallback(frameCallback);
            }

            invalidate();
            return true;
        }

        @Override
        protected void onDraw(Canvas canvas) {
            final long drawNano = System.nanoTime();
            super.onDraw(canvas);

            // Draw minimal feedback circle
            if (isTouching && lastX >= 0 && lastY >= 0) {
                paint.setColor(Color.parseColor("#10B981"));
                canvas.drawCircle(lastX, lastY, 40, paint);
                paint.setColor(Color.WHITE);
                canvas.drawCircle(lastX, lastY, 15, paint);
            }

            if (!pendingEvents.isEmpty()) {
                List<EventRecord> processing = new ArrayList<>(pendingEvents);
                pendingEvents.clear();

                EventRecord latest = null;
                for (EventRecord record : processing) {
                    if (record.choreographerFrameNano == 0) {
                        record.choreographerFrameNano = (lastChoreographerFrameNano > 0)
                            ? lastChoreographerFrameNano
                            : drawNano;
                    }
                    record.drawNano = drawNano;

                    if (record.choreographerFrameNano > record.receiveNano) {
                        record.dispatchToFrameMs = (record.choreographerFrameNano - record.receiveNano) / 1_000_000.0;
                    } else {
                        record.dispatchToFrameMs = 0.0;
                    }

                    if (record.drawNano > record.choreographerFrameNano) {
                        record.frameToDrawMs = (record.drawNano - record.choreographerFrameNano) / 1_000_000.0;
                    } else {
                        record.frameToDrawMs = 0.0;
                    }

                    double dispatchToDrawMs = (record.drawNano > record.receiveNano)
                        ? (record.drawNano - record.receiveNano) / 1_000_000.0
                        : 0.0;
                    record.eventToDrawMs = record.eventToDispatchMs + dispatchToDrawMs;

                    String json = String.format(Locale.US,
                        "{\"schemaVersion\":%d,\"sequenceId\":%d,\"gestureId\":%d,\"action\":\"%s\",\"actionCode\":%d,\"eventUptime\":%d,\"receiveUptime\":%d,\"receiveNano\":%d,\"choreographerFrameNano\":%d,\"drawNano\":%d,\"x\":%.1f,\"y\":%.1f,\"eventToDispatchMs\":%.3f,\"dispatchToFrameMs\":%.3f,\"frameToDrawMs\":%.3f,\"eventToDrawMs\":%.3f}",
                        record.schemaVersion, record.sequenceId, record.gestureId, record.action, record.actionCode,
                        record.eventUptime, record.receiveUptime, record.receiveNano, record.choreographerFrameNano,
                        record.drawNano, record.x, record.y, record.eventToDispatchMs, record.dispatchToFrameMs,
                        record.frameToDrawMs, record.eventToDrawMs
                    );
                    Log.i(TAG, "INPUT_PROBE_JSON: " + json);
                    latest = record;
                }

                if (!isCanonicalMode && latest != null) {
                    tvStats.setText(String.format(Locale.US,
                        "Input Probe #%03d (Gest #%d) | Action: %s\nEvent -> Recv Dispatch : %.2f ms\nDispatch -> Choreo Frame: %.2f ms\nChoreo -> View onDraw  : %.2f ms\nTotal Event -> Draw     : %.2f ms\nPosition: (%.0f, %.0f)",
                        latest.sequenceId, latest.gestureId, latest.action,
                        latest.eventToDispatchMs, latest.dispatchToFrameMs, latest.frameToDrawMs, latest.eventToDrawMs,
                        latest.x, latest.y
                    ));
                }
            }
        }
    }
}

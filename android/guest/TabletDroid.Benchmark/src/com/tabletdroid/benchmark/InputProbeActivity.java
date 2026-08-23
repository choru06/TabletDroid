package com.tabletdroid.benchmark;

import android.app.Activity;
import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.os.Bundle;
import android.util.Log;
import android.view.Choreographer;
import android.view.MotionEvent;
import android.view.View;
import android.widget.FrameLayout;
import android.widget.TextView;

import java.util.concurrent.atomic.AtomicInteger;

public class InputProbeActivity extends Activity {
    public static final String TAG = "TabletDroidInputProbe";
    private static final AtomicInteger sequenceCounter = new AtomicInteger(0);

    private ProbeTouchView touchView;
    private TextView tvStats;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

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
        tvStats.setText("Input Latency Diagnostic Probe Active\nTap anywhere on the screen to measure latency.");
        root.addView(tvStats);

        setContentView(root);
        Log.i(TAG, "InputProbeActivity created and ready for input latency diagnostic probing.");
    }

    private class ProbeTouchView extends View {
        private final Paint paint = new Paint();
        private float lastX = -100;
        private float lastY = -100;
        private boolean isTouching = false;

        public ProbeTouchView(Context context) {
            super(context);
            paint.setAntiAlias(true);
            paint.setColor(Color.parseColor("#10B981")); // Emerald 500
            paint.setStyle(Paint.Style.FILL);
        }

        @Override
        public boolean onTouchEvent(MotionEvent event) {
            final int seq = sequenceCounter.incrementAndGet();
            final long recvUptimeMs = android.os.SystemClock.uptimeMillis();
            final long eventUptimeMs = event.getEventTime();
            final int action = event.getActionMasked();

            lastX = event.getX();
            lastY = event.getY();
            isTouching = (action != MotionEvent.ACTION_UP && action != MotionEvent.ACTION_CANCEL);
            invalidate();

            final double guestDispatchDelayMs = (eventUptimeMs > 0 && recvUptimeMs >= eventUptimeMs)
                ? (recvUptimeMs - eventUptimeMs)
                : 0.0;

            final long recvNano = System.nanoTime();

            Choreographer.getInstance().postFrameCallback(new Choreographer.FrameCallback() {
                @Override
                public void doFrame(long frameTimeNano) {
                    final double guestToChoreographerDelayMs = (frameTimeNano > recvNano)
                        ? (frameTimeNano - recvNano) / 1_000_000.0
                        : 0.0;

                    final double totalGuestDelayMs = guestDispatchDelayMs + guestToChoreographerDelayMs;

                    String json = String.format(
                        "{\"seq\":%d,\"action\":%d,\"eventUptimeMs\":%d,\"recvUptimeMs\":%d,\"guestDispatchDelayMs\":%.3f,\"guestToChoreographerDelayMs\":%.3f,\"totalGuestDelayMs\":%.3f,\"x\":%.1f,\"y\":%.1f}",
                        seq, action, eventUptimeMs, recvUptimeMs, guestDispatchDelayMs, guestToChoreographerDelayMs, totalGuestDelayMs, lastX, lastY
                    );
                    Log.i(TAG, "INPUT_PROBE_JSON: " + json);

                    tvStats.setText(String.format(
                        "Input Probe #%03d | Action: %d\nGuest Dispatch Delay     : %.2f ms\nGuest -> Choreographer   : %.2f ms\nTotal Guest Delay         : %.2f ms\nPosition: (%.0f, %.0f)",
                        seq, action, guestDispatchDelayMs, guestToChoreographerDelayMs, totalGuestDelayMs, lastX, lastY
                    ));
                }
            });

            return true;
        }

        @Override
        protected void onDraw(Canvas canvas) {
            super.onDraw(canvas);
            if (isTouching && lastX >= 0 && lastY >= 0) {
                paint.setColor(Color.parseColor("#10B981"));
                canvas.drawCircle(lastX, lastY, 60, paint);
                paint.setColor(Color.WHITE);
                canvas.drawCircle(lastX, lastY, 20, paint);
            }
        }
    }
}

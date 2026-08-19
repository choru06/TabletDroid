using System;
using System.Collections.Generic;
using System.Linq;
using Xunit;

namespace TabletDroid.Tests;

public class BenchmarkMetricsTests
{
    public class BenchmarkResult
    {
        public string Scenario { get; set; } = string.Empty;
        public int ValidFrames { get; set; }
        public double DurationSec { get; set; }
        public double ObservedThroughputFps => DurationSec > 0 ? Math.Round(ValidFrames / DurationSec, 2) : 0;
        public double FrameLatencyAvgMs { get; set; }
        public double LatencyEquivalentFps => FrameLatencyAvgMs > 0 ? Math.Round(1000.0 / FrameLatencyAvgMs, 2) : 0;
        public double P50Ms { get; set; }
        public double P90Ms { get; set; }
        public double P99Ms { get; set; }
        public double JankPercent { get; set; }
        public bool IsValid => ValidFrames >= 15;
        public string Status => IsValid ? "VALID" : "INVALID / INSUFFICIENT_SAMPLES";
    }

    [Fact]
    public void ThroughputAndLatencyFps_AreDistinguishedCorrectly()
    {
        // 10초 동안 120프레임 관측, 평균 프레임 지연은 42.86ms인 경우
        var result = new BenchmarkResult
        {
            Scenario = "1920x1200 SurfaceFlinger Both",
            ValidFrames = 120,
            DurationSec = 10.0,
            FrameLatencyAvgMs = 42.86
        };

        Assert.Equal(12.0, result.ObservedThroughputFps);
        Assert.Equal(23.33, result.LatencyEquivalentFps);
        Assert.NotEqual(result.ObservedThroughputFps, result.LatencyEquivalentFps);
        Assert.True(result.IsValid);
        Assert.Equal("VALID", result.Status);
    }

    [Fact]
    public void LowFrameSample_IsClassifiedAsInsufficientSamples()
    {
        // 2개 프레임만 수집된 비정상 샘플
        var invalidResult = new BenchmarkResult
        {
            Scenario = "1280x800 Erroneous Sample",
            ValidFrames = 2,
            DurationSec = 6.0,
            FrameLatencyAvgMs = 250.0
        };

        Assert.False(invalidResult.IsValid);
        Assert.Equal("INVALID / INSUFFICIENT_SAMPLES", invalidResult.Status);
    }

    [Fact]
    public void PercentileCalculation_IsExact()
    {
        var samples = new List<double> { 10, 12, 14, 16, 18, 20, 25, 30, 40, 100 };
        samples.Sort();

        int p50Idx = (int)Math.Min(samples.Count * 0.50, samples.Count - 1);
        int p90Idx = (int)Math.Min(samples.Count * 0.90, samples.Count - 1);
        int p99Idx = (int)Math.Min(samples.Count * 0.99, samples.Count - 1);

        Assert.Equal(20, samples[p50Idx]);
        Assert.Equal(100, samples[p90Idx]);
        Assert.Equal(100, samples[p99Idx]);
    }

    [Fact]
    public void MultiTrialStatistics_CalculatesMedianMinMaxStdDev()
    {
        var trialFps = new List<double> { 20.0, 22.0, 23.5, 24.0, 21.5 };
        trialFps.Sort();

        double median = trialFps[trialFps.Count / 2];
        double min = trialFps.Min();
        double max = trialFps.Max();
        double avg = trialFps.Average();
        double variance = trialFps.Select(x => Math.Pow(x - avg, 2)).Average();
        double stdDev = Math.Round(Math.Sqrt(variance), 2);

        Assert.Equal(22.0, median);
        Assert.Equal(20.0, min);
        Assert.Equal(24.0, max);
        Assert.True(stdDev > 0 && stdDev < 2.0);
    }
}

#include <math.h>
#include <pulse/error.h>
#include <pulse/simple.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

enum {
  sample_rate = 44100,
  frames_per_second = 30,
  frames_per_read = sample_rate / frames_per_second,
  channels = 2,
  peak_hold_frames = 14,
};

static double clamp01(double value) {
  if (value < 0.0)
    return 0.0;
  if (value > 1.0)
    return 1.0;
  return value;
}

static double db_level(double amplitude) {
  if (amplitude <= 0.0)
    return 0.0;
  return clamp01((20.0 * log10(amplitude) + 48.0) / 48.0);
}

int main(void) {
  const char *device = getenv("AUDIO_METER_DEVICE");
  if (device == NULL || device[0] == '\0')
    device = "@DEFAULT_MONITOR@";

  const pa_sample_spec sample_spec = {
      .format = PA_SAMPLE_FLOAT32LE,
      .rate = sample_rate,
      .channels = channels,
  };
  const uint32_t fragment_bytes =
      (uint32_t)(frames_per_read * channels * sizeof(float));
  const pa_buffer_attr buffer_attr = {
      .maxlength = UINT32_MAX,
      .tlength = UINT32_MAX,
      .prebuf = UINT32_MAX,
      .minreq = UINT32_MAX,
      .fragsize = fragment_bytes,
  };

  int error = 0;
  pa_simple *capture = pa_simple_new(
      NULL, "quickshell-cliamp-visualiser", PA_STREAM_RECORD, device,
      "stereo audio meter", &sample_spec, NULL, &buffer_attr, &error);
  if (capture == NULL) {
    fprintf(stderr, "audio-meter: %s\n", pa_strerror(error));
    return 1;
  }

  float samples[frames_per_read * channels];
  double level[channels] = {0.0, 0.0};
  double peak[channels] = {0.0, 0.0};
  int peak_hold[channels] = {0, 0};
  setvbuf(stdout, NULL, _IOLBF, 0);

  for (;;) {
    if (pa_simple_read(capture, samples, sizeof(samples), &error) < 0) {
      fprintf(stderr, "audio-meter: %s\n", pa_strerror(error));
      pa_simple_free(capture);
      return 1;
    }

    double sum_squares[channels] = {0.0, 0.0};
    double sample_peak[channels] = {0.0, 0.0};
    for (int frame = 0; frame < frames_per_read; frame++) {
      for (int channel = 0; channel < channels; channel++) {
        const double value = samples[frame * channels + channel];
        sum_squares[channel] += value * value;
        const double magnitude = fabs(value);
        if (magnitude > sample_peak[channel])
          sample_peak[channel] = magnitude;
      }
    }

    for (int channel = 0; channel < channels; channel++) {
      const double target_level =
          db_level(sqrt(sum_squares[channel] / frames_per_read));
      const double target_peak = db_level(sample_peak[channel]);
      const double rate = target_level > level[channel] ? 36.0 : 10.0;
      const double alpha = 1.0 - exp(-rate / frames_per_second);
      level[channel] += (target_level - level[channel]) * alpha;

      if (target_peak > peak[channel]) {
        peak[channel] = target_peak;
        peak_hold[channel] = peak_hold_frames;
      } else if (peak_hold[channel] > 0) {
        peak_hold[channel]--;
      } else {
        peak[channel] = fmax(
            level[channel], peak[channel] - 0.65 / frames_per_second);
      }
    }

    if (printf("{\"levels\":[%.6f,%.6f],\"peaks\":[%.6f,%.6f]}\n",
               level[0], level[1], peak[0], peak[1]) < 0) {
      pa_simple_free(capture);
      return 0;
    }
  }
}

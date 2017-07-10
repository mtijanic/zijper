/**
 * @file
 * @brief   Framerate tracking
 * @author  mtijanic
 * @license GPL-2.0
 */
#include "stdint.h"
#include "stdio.h"
#include "time.h"


#define MAX_FRAMES_PER_SECOND 4000
static struct {
    time_t init_time;
    time_t last_frame_time;
    uint32_t frames_this_second;
    uint64_t total_frames;
    uint32_t fps_histogram[MAX_FRAMES_PER_SECOND+1];
} frame_data;


void framerate_init(void) __attribute__((constructor));
void framerate_init(void)
{
    frame_data.init_time = time(NULL);
}

void framerate_notify_frame(void)
{
    time_t now = time(NULL);
    if (now == frame_data.last_frame_time)
    {
        frame_data.frames_this_second++;
    }
    else
    {
        frame_data.total_frames += frame_data.frames_this_second;

        if (frame_data.frames_this_second > MAX_FRAMES_PER_SECOND)
            frame_data.frames_this_second = MAX_FRAMES_PER_SECOND;

        frame_data.fps_histogram[frame_data.frames_this_second]++;
        frame_data.frames_this_second = 1;
        frame_data.last_frame_time = now;
    }
}

void framerate_print_report(FILE *f)
{
    uint32_t runtime = frame_data.last_frame_time - frame_data.init_time;
    fprintf(f, "Runtime: %u seconds\n", runtime);
    fprintf(f, "Total frames: %llu\n", frame_data.total_frames);
    fprintf(f, "Average fps: %f\n", (float)frame_data.total_frames / runtime);

    fprintf(f, "Framerate histogram: \n");
    static const char bar[100] =
                "++++++++++++++++++++++++++++++++++++++++++++++++++"
                "++++++++++++++++++++++++++++++++++++++++++++++++++";

    for (int i = 0; i <= MAX_FRAMES_PER_SECOND; i++)
    {
        uint32_t fps = frame_data.fps_histogram[i];
        if (fps == 0) continue;

        uint32_t bar_length = ((double)fps * sizeof(bar)) / runtime;
        fprintf(f, "\tfps[%4d]: %4u: %.*s\n", i, fps, bar_length, bar);
    }
}

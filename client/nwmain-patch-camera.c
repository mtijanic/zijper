/**
 * @file
 * @brief   nwmain patches to unlock camera angles
 * @author  mtijanic
 * @license GPL-2.0
 */

#include "zijper-client.h"


void nwmain_patch_camera(void) __attribute__((constructor));

void nwmain_patch_camera(void)
{
    const float camera_distance_min = -0.25f; // Original: 1.0f
    const float camera_distance_max = 100.0f; // Original: 25.0f
    const float camera_angle_min    =   0.0f; // Original: 1.0f
    const float camera_angle_max    = 200.0f; // Original: 89.0f
    const float fog_distance        =  90.0f; // Original: 45.0f

    apply_patch(0x81a6a62, &camera_distance_min, sizeof(camera_distance_min));
    apply_patch(0x81a6d62, &camera_distance_min, sizeof(camera_distance_min));

    apply_patch(0x81a6a6c, &camera_distance_max, sizeof(camera_distance_max));
    apply_patch(0x81a6d6c, &camera_distance_max, sizeof(camera_distance_max));

    apply_patch(0x81a6a76, &camera_angle_min, sizeof(camera_angle_min));
    apply_patch(0x81a6d76, &camera_angle_min, sizeof(camera_angle_min));

    apply_patch(0x81a6a80, &camera_angle_max, sizeof(camera_angle_max));
    apply_patch(0x81a6d80, &camera_angle_max, sizeof(camera_angle_max));

    apply_patch(0x84c767b, &fog_distance, sizeof(fog_distance));

    const uint8_t dist_max = 0xa0; // Original 0xe4
    apply_patch(0x81a6a68, &dist_max, sizeof(dist_max));

    const uint8_t max_effect_icons = 0xfe; // Original 0x81
    apply_patch(0x80c4df9, &max_effect_icons, sizeof(max_effect_icons));
}

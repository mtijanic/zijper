/**
 * @file
 * @brief   nwmain patches required for game functionality
 * @author  mtijanic
 * @license GPL-2.0
 */

#include "zijper-client.h"


void nwmain_patch_functional(void) __attribute__((constructor));


static int GuiButtonListbox__InsertButton_SkipSkills(int this, int skillbutton, int index, int nSkill);

void nwmain_patch_functional(void)
{
    //
    // Old: 0f b6 05 fa e0 5f 08    movzx  eax,BYTE PTR ds:0x85fe0fa
    // New: b8 7f 00 00 00          mov    eax,0x7f
    //      90                      nop
    //      90                      nop
    //
    // Code is trying to load the index of the Wizard class into EAX to
    // use as a limit how many GUI listbox items to mark as enabled.
    // Patch hardcodes this to 0x7f instead.
    //
    const uint8_t class_list_patch[] = {0xb8, 0x7f, 0x00, 0x00, 0x00, 0x90, 0x90};
    apply_patch(0x82320b0, class_list_patch, sizeof(class_list_patch));

    //
    // Called to add a skill to the list at character creation.
    // Skip the skills that are disabled.
    //
    single_call_detour(0x824cf90, GuiButtonListbox__InsertButton_SkipSkills);
}

int GuiButtonListbox__InsertButton_SkipSkills(int this, int skillbutton, int index, int nSkill)
{
    int (*GuiButtonListbox__InsertButton)(int,int,int,int) = (void*)0x84B0640;

    switch (nSkill)
    {
        case 6:    // XXX_Listen
        case 8:    // XXX_MoveSilently
        case 9:    // XXX_OpenLock
        case 14:   // XXX_Search
        case 15:   // XXX_SetTrap
            /// @todo Destroy the button afterwards.
            return 0;
    }
    return GuiButtonListbox__InsertButton(this, skillbutton, index, nSkill);
}

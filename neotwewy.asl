state("NEO The World Ends with You") {
    int day: "GameAssembly.dll", 0x2506d68, 0x30, 0, 0xb8, 0, 0x28;
}

startup {
    Assembly.Load(File.ReadAllBytes("Components/asl-help")).CreateInstance("Unity");
}

init {
    vars.gameobject = IntPtr.Zero;
    vars.loading = null;
    
    vars.Helper.TryLoad = (Func<dynamic, bool>)(mono => {
        vars.Helper["UIs"] = mono["UIManager", 1].Make<IntPtr>("msInstance", "mUIs");

        vars.Helper["end"] = mono["BattleScene", 2].Make<bool>(
            "msInstance",
            // mSeq
            0xb8,
            // BattleSceneSequence::mLastBossFinishSeq
            0x28,
            // BattleSceneLastBossFinishSequence::mRindoAttackGuideUI
            0x90,
            // LastBattleRindoAttackButtonGuide::IsPush
            0x50);

        //print(mono["FieldManager", 1].Static.ToString("X"));
        vars.Helper["mapload"] = mono["FieldManager", 1].Make<IntPtr>(
            "mInstance",
            // FieldManager::m_FieldMapDataManager
            0x58);

        vars.Helper["mapload"].FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull;
        //vars.Helper["fieldstate"] = mono["FieldManager", 1].Make<int>("mInstance", "m_FieldState");
        //vars.Helper["fieldstate"].FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull;
        return true;
    });
}

isLoading {
    if (vars.gameobject == IntPtr.Zero) {
        // Iterate through the entries of a `Dictionary<int, GameObject>`.

        // number of entries
        int count = memory.ReadValue<int>((IntPtr)current.UIs + 0x20);
        // Each entry is 0x20 bytes.
        int max = count * 0x20;
        IntPtr entries = memory.ReadPointer((IntPtr)current.UIs + 0x18);

        // TODO: Just read the whole list of entries at once.
        for (int offset = 0x28; offset < max; offset += 0x20) {
            int key = memory.ReadValue<int>(entries + offset);
            
            if (key == 0x102) {
                vars.gameobject = memory.ReadPointer(entries + offset + 8);
                print("gameobject found at " + vars.gameobject.ToString("X"));
                break;
            }
        }
    } else if (vars.loading == null) {
        // We need to get the LoadingUI component from the game object that we have.

        // Unity::GameObject.m_cachedPtr
        // This is the il2cpp GameObject, not Unity::GameObject.
        IntPtr rawGameObject = memory.ReadPointer((IntPtr)vars.gameobject + 0x10);

        // GameObject.m_Component.m_size
        int size = memory.ReadValue<int>(rawGameObject + 0x40);

        // GameObject.m_Component.m_ptr (ComponentPair[size])
        IntPtr m_ptr = memory.ReadPointer(rawGameObject + 0x30);
        int max = size * 0x10;
        for (int offset = 8; offset < max; offset += 0x10 ) {
            // GameObject.m_Component.m_ptr[n].component
            IntPtr component = memory.ReadPointer(m_ptr + offset);

            // This is a hack.
            string name = new DeepPointer(component + 0x28, 0, 0x10, 0).DerefString(game, 255);

            if (name.Equals("LoadingUI")) {
                // Component.m_GameObject.m_ptr->m_IsActive
                vars.loading = new DeepPointer(component + 0x30, 0x56);
                print("LoadingUI found at " + component.ToString("X"));
                break;
            }
        }
    } else {
        //IntPtr controller = memory.ReadPointer((IntPtr)current.mapload + 0x38);
        //IntPtr isLoad = memory.ReadPointer(controller + 0x18);

        // Check to make sure the pointer isn't null before dereferencing.
        if (current.mapload != IntPtr.Zero && memory.ReadValue<byte>((IntPtr)current.mapload + 0x30) == 0) {
            return true;
        }

        if (vars.loading.Deref<bool>(game)) {
            print("loading");
            return true;
        }

        return false;
    }
}

split {
    return current.day > old.day || (current.end && !old.end);
}

exit {
    vars.gameobject = IntPtr.Zero;
}
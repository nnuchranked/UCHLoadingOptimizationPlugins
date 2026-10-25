using System;
using System.Collections.Generic;
using BepInEx;
using HarmonyLib;

[BepInPlugin("com.you.uch.listenerfix", "UCH Listener Fix", "0.1.0")]
public class ListenerFix : BaseUnityPlugin
{
    static readonly HashSet<int> Registered = new HashSet<int>();
    static bool enabled = true;

    void Awake()
    {
        enabled = Config.Bind("ListenerFix", "Enabled", true, "Skip the O(n) Contains scan when placeables register for events. Restart required.").Value;
        if (!enabled) { Logger.LogInfo("ListenerFix disabled by config."); return; }
        Harmony h = new Harmony("com.you.uch.listenerfix");
        h.Patch(AccessTools.DeclaredMethod(typeof(Placeable), "ChangeListener"), new HarmonyMethod(typeof(ListenerFix), "Prefix"));
        Logger.LogInfo("ListenerFix patched Placeable.ChangeListener.");
    }

    public static bool Prefix(Placeable __instance, bool adding)
    {
        if (!enabled) return true;
        try
        {
            int id = __instance.GetInstanceID();
            if (!adding) { Registered.Remove(id); return true; }   // removal stays vanilla
            if (!Registered.Add(id)) return false;                 // already registered by us
            Add(typeof(GameEvent.StartPhaseEvent), __instance);
            Add(typeof(GameEvent.ScoreboardEvent), __instance);
            Add(typeof(GameEvent.PauseEvent), __instance);
            Add(typeof(GameEvent.EndPhaseEvent), __instance);
            Add(typeof(GameEvent.LevelResetEvent), __instance);
            return false;
        }
        catch (Exception e)
        {
            enabled = false;
            UnityEngine.Debug.LogError("ListenerFix disabled after error: " + e);
            return true;   // original still dedupes with Contains
        }
    }

    static void Add(Type type, GameEvent.IGameEventListener listener)
    {
        var dict = GameEvent.GameEventManager.listeners;
        List<GameEvent.IGameEventListener> list;
        if (!dict.TryGetValue(type, out list)) { list = new List<GameEvent.IGameEventListener>(); dict.Add(type, list); }
        list.Add(listener);
    }
}
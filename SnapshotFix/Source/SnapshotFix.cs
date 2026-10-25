using System;
using System.Collections;
using System.Collections.Generic;
using System.Reflection;
using BepInEx;
using HarmonyLib;
using UnityEngine;
using UnityEngine.Networking;

[BepInPlugin("com.you.uch.snapshotfix", "UCH Snapshot Fix", "0.1.0")]
public class SnapshotFix : BaseUnityPlugin
{
    static FieldInfo loadingField;
    static MethodInfo waitMethod;
    static bool enabled = true;

    void Awake()
    {
        enabled = Config.Bind("SnapshotFix", "SkipCompressionWhenOffline", true,
            "Skip LZMA compression and snapshot sending when no other player is in the game. Restart required.").Value;
        if (Config.Bind("SnapshotFix", "FasterCompressionOnline", false,
            "EXPERIMENT: use cheaper LZMA settings (fast bytes 32, bt2) when hosting online. Restart required.").Value)
            TuneCompression();
        if (!enabled) { Logger.LogInfo("SnapshotFix disabled by config."); return; }
        loadingField = AccessTools.Field(typeof(GameControl), "playerNumbersStillLoadingSnapshot");
        waitMethod = AccessTools.Method(typeof(GameControl), "WaitForAllClientsToLoadSnapshot");
        MethodInfo target = AccessTools.DeclaredMethod(typeof(GameControl), "CompressAndSendSnapshotBytes");
        if (loadingField == null || waitMethod == null || target == null) { Logger.LogWarning("SnapshotFix: members not found, not patching."); return; }
        new Harmony("com.you.uch.snapshotfix").Patch(target, new HarmonyMethod(typeof(SnapshotFix), "Prefix"));
        Logger.LogInfo("SnapshotFix patched GameControl.CompressAndSendSnapshotBytes.");
    }

    void TuneCompression()
    {
        try
        {
            FieldInfo f = AccessTools.Field(typeof(SevenZip.Compression.LZMA.SevenZipHelper), "properties");
            object[] props = (object[])f.GetValue(null);
            props[5] = 32;      // NumFastBytes
            props[6] = "bt2";   // MatchFinder
            Logger.LogInfo("SnapshotFix: faster LZMA settings applied (online hosting only).");
        }
        catch (Exception e) { Logger.LogWarning("SnapshotFix: could not tune compression: " + e.Message); }
    }

    public static bool Prefix(GameControl __instance, byte[] bytes, UnityEngine.Events.UnityAction onAllClientsLoadedSnapshot)
    {
        try
        {
            if (!enabled || !__instance.hasAuthority) return true;
            if (LobbyManager.instance.IsInOnlineGame) return true;
            foreach (object id in LobbyManager.instance.PlayerTracker.GetAllGameNetIDs())
            {
                GameObject go = ClientScene.FindLocalObject(new NetworkInstanceId(Convert.ToUInt32(id)));
                if (go == null) continue;
                GamePlayer gp = go.GetComponent<GamePlayer>();
                if (gp != null && !gp.IsLocalPlayer) return true;   // a remote player exists: vanilla path
            }
            // Same state vanilla leaves when nobody remote is loading, then the same wait coroutine.
            loadingField.SetValue(__instance, new List<int>());
            IEnumerator wait = (IEnumerator)waitMethod.Invoke(__instance, new object[] { onAllClientsLoadedSnapshot });
            __instance.StartCoroutine(wait);
            return false;
        }
        catch (Exception)
        {
            enabled = false;   // fall back to vanilla for the rest of the session
            return true;
        }
    }
}
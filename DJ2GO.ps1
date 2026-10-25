
$ErrorActionPreference = 'Stop'
$handle = [IntPtr]::Zero

try {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class DJ2GOMini {
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Auto)]
    public struct Caps {
        public ushort mid, pid;
        public uint version;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)]
        public string name;
        public ushort technology, voices, notes, channels;
        public uint support;
    }

    [DllImport("winmm.dll")]
    public static extern uint midiOutGetNumDevs();

    [DllImport("winmm.dll", CharSet=CharSet.Auto)]
    public static extern uint midiOutGetDevCaps(
        UIntPtr id, out Caps caps, uint size);

    [DllImport("winmm.dll")]
    public static extern uint midiOutOpen(
        out IntPtr handle, uint id, IntPtr callback,
        IntPtr instance, uint flags);

    [DllImport("winmm.dll")]
    public static extern uint midiOutShortMsg(IntPtr handle, uint message);

    [DllImport("winmm.dll")]
    public static extern uint midiOutReset(IntPtr handle);

    [DllImport("winmm.dll")]
    public static extern uint midiOutClose(IntPtr handle);

    public static string GetName(int id) {
        Caps c;
        uint r = midiOutGetDevCaps(new UIntPtr((uint)id),
            out c, (uint)Marshal.SizeOf(typeof(Caps)));
        return r == 0 ? c.name : "";
    }

    public static IntPtr Open(int id) {
        IntPtr h;
        uint r = midiOutOpen(out h, (uint)id,
            IntPtr.Zero, IntPtr.Zero, 0);
        if (r != 0) throw new Exception("MIDI open error: " + r);
        return h;
    }

    public static void Send(IntPtr h, int note, int velocity) {
        uint msg = (uint)(0x90 | (note << 8) | (velocity << 16));
        uint r = midiOutShortMsg(h, msg);
        if (r != 0) throw new Exception("MIDI send error: " + r);
    }

    public static void Close(IntPtr h) {
        if (h != IntPtr.Zero) {
            midiOutReset(h);
            midiOutClose(h);
        }
    }
}
'@

    $count = [int][DJ2GOMini]::midiOutGetNumDevs()
    $device = -1
    $fallback = -1

    for ($i = 0; $i -lt $count; $i++) {
        $name = [DJ2GOMini]::GetName($i)

        if ($name -match '(?i)DJ[\s_-]*2GO') {
            $device = $i
            break
        }

        if ($fallback -lt 0 -and $name -match '(?i)ION|Numark') {
            $fallback = $i
        }
    }

    if ($device -lt 0) {
        $device = $fallback
    }

    if ($device -lt 0) {
        throw 'DJ2GO MIDI output not found.'
    }

    $handle = [DJ2GOMini]::Open($device)

    [int[]]$notes = @(0x33, 0x3B, 0x40, 0x65, 0x3C, 0x42, 0x47, 0x66)
    $states = @{}
    foreach ($note in $notes) {
        $states[$note] = $false
        [DJ2GOMini]::Send($handle, $note, 0)
    }

    $random = [System.Random]::new()
    $clock = [System.Diagnostics.Stopwatch]::StartNew()
    [long]$nextTick = 0

    while ($true) {
        foreach ($note in $notes) {
            if ($random.Next(100) -lt 20) {
                $states[$note] = -not [bool]$states[$note]
                $velocity = if ($states[$note]) { 127 } else { 0 }
                [DJ2GOMini]::Send($handle, $note, $velocity)
            }
        }

        $nextTick += 100
        $remaining = $nextTick - $clock.ElapsedMilliseconds

        if ($remaining -gt 0) {
            Start-Sleep -Milliseconds ([int]$remaining)
        } elseif ($remaining -lt -400) {
            $nextTick = $clock.ElapsedMilliseconds
        }
    }
}
finally {
    if ($handle -ne [IntPtr]::Zero) {
        foreach ($note in @(0x33, 0x3B, 0x40, 0x65, 0x3C, 0x42, 0x47, 0x66)) {
            try {
                [DJ2GOMini]::Send($handle, $note, 0)
            } catch {}
        }

        [DJ2GOMini]::Close($handle)
    }
}

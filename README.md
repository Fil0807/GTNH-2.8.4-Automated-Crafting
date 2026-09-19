# GTNH 2.8.4 Automated Crafting

OpenComputers 1.8.9 Lua program for GTNH 2.8.4.

## Behaviour

1. Reads the Lapotronic Supercapacitor wireless EU level.
2. Pauses autocrafting below the configured EU threshold.
3. Checks only configured AE2 items with `getItemsInNetworkById({id})`.
4. Identifies items by registry `name + damage`; labels are display-only.
5. When stock is below `minQty`, searches AE2 crafting patterns with `getCraftables({name=...})` and then performs the exact `name + damage` check locally.
6. Starts `Craftable:request(amount)` when an exact pattern is found.
7. Tracks the returned crafting-status object and avoids overlapping crafts according to the configured settings.

## Important AE2 compatibility detail

On this GTNH/OC setup, `getCraftables({name=..., damage=...})` did not return the Titanium Plate pattern even though the pattern exists. `getCraftables({name=...})` returned the pattern, and `Craftable:getItemStack()` reported:

- name: `gregtech:gt.metaitem.01`
- damage: `17028`
- label: `Titanium Plate`

The program therefore uses the name-only filter and verifies the exact damage itself.

## Installation

Copy the archive contents to the OpenComputers computer, preserving:

```text
main.lua
config.lua
lib/
tests/
```

Run:

```text
main
```

## Configuration

Edit `config.lua`.

`pollInterval` is in seconds.

Default Titanium Plate target:

```lua
{
  label = "Titanium Plate",
  id = 7437,
  name = "gregtech:gt.metaitem.01",
  damage = 17028,
  minQty = 100000,
  craftAmount = 10000,
}
```

The Gallifreyan Stabilisation Field Generator example remains commented out.

## Diagnostic test

To verify the Titanium Plate craftable independently:

```text
lua /home/tests/test-craftable.lua
```

The test ends with:

```text
FOUND = true
```

when the exact `name + damage` craftable is present.


## v8 change

Craftable lookup continues to mirror the verified diagnostic test exactly: `getCraftables({name = target.name})`, then `Craftable:getItemStack()` and exact `name + damage` comparison. The combined name+damage AE2 filter is deliberately not used because it misses the verified Titanium Plate pattern in this GTNH/OC environment.

## v8 change

Crafting jobs are now tracked independently per target using the `CraftingStatus` returned by `Craftable:request()`.

Example:
- Titanium Plate x10,000 is active -> another Titanium Plate request is blocked.
- Stabilisation Field Generator is below its threshold at the same time -> it can still start, subject to `maxCraftsPerCycle` and available AE2 resources/CPUs.
- When the Titanium Plate job is `isDone()` or `isCanceled()`, the next cycle may request another Titanium Plate batch.

The old global "any active craft blocks everything" behavior has been removed.

## v8

The archive is flat: `main.lua`, `config.lua`, `lib/`, and `tests/` are directly at the archive root. The AE2 module exposes `ae2.VERSION = "v7"`; main.lua prints it at startup so a stale `/home/lib/ae2.lua` is immediately detectable.

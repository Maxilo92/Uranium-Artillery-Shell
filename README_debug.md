# Uranium Artillery Shell - Debug Mode

Use `/uranium-debug` to toggle debug visualization and messages.

- Shows green aura clouds (`uranium-radiation-aura-debug`) around irradiated or mutated carriers.
- Prints counts of carriers and infection events.
- Editor-placed mutated entities (`mutated-*`) automatically act as contagion carriers.

Test:
1. Open a world, find a big nest.
2. Enter editor, place a `mutated-big-biter` into the nest.
3. Run `/uranium-debug`.
4. You should see green auras and infections within ~1s.

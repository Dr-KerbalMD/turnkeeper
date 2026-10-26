// Exports the iconic pregens' statistics, as Foundry works them out, for Turnkeeper's Table Buddies.
//
// The iconics compendium stores how each pregen is built (boosts, ranks and items); Foundry computes the AC,
// saves, skills, strikes and spell DCs when it prepares the actor, so the numbers can only be read from a
// running world. Rerun this when the pf2e or sf2e system updates its iconics.
//
// To run it: in a Pathfinder 2e world (and again in a Starfinder 2e world), create a Script macro, paste this
// file into it and execute it as a GM. The browser downloads pf2e-pregens.json (or sf2e-pregens.json); put
// it in Sources/TurnkeeperKit/Resources/Pregens/.

const pack = game.packs.find((p) => p.documentName === "Actor" && p.metadata.name === "iconics");
if (!pack) {
    ui.notifications.error("Exporting the pregens failed: this world's system has no iconics compendium.");
    return;
}
ui.notifications.info(`Exporting the pregens from ${pack.title}…`);

const text = (html) => (html ?? "")
    .replace(/<br\s*\/?>|<\/p>|<\/li>/gi, "\n")
    .replace(/<[^>]+>/g, "")
    .replace(/@UUID\[[^\]]*\]\{([^}]*)\}/g, "$1")
    .replace(/@\w+\[[^\]]*\]\{([^}]*)\}/g, "$1")
    .replace(/&nbsp;/g, " ")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
const baseName = (name) => name.replace(/\s*\(Level \d+\)\s*$/i, "").trim();
const slug = (name) => baseName(name).toLowerCase().normalize("NFD").replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
const names = (items) => items.map((item) => item.name);

async function strikes(actor) {
    const result = [];
    for (const strike of (actor.system.actions ?? []).filter((a) => a.type === "strike" && a.visible !== false)) {
        let damage = "";
        try {
            damage = String(await strike.damage({ getFormula: true }));
        } catch (error) {
            console.warn(`Turnkeeper export: no damage for ${actor.name}'s ${strike.label}`, error);
        }
        result.push({
            name: strike.label,
            attack: strike.totalModifier,
            damage,
            traits: (strike.weaponTraits ?? strike.traits ?? []).map((t) => t.label ?? t.name ?? String(t)),
            ranged: strike.item?.isRanged ?? false,
        });
    }
    return result;
}

async function spellcasting(actor) {
    const result = [];
    for (const entry of actor.spellcasting?.contents ?? []) {
        if (!entry.spells || entry.spells.size === 0) continue;
        const spells = entry.spells.contents.map((spell) => ({
            name: spell.name,
            rank: spell.isCantrip ? 0 : (spell.rank ?? spell.level ?? 0),
            isCantrip: spell.isCantrip ?? false,
            isFocus: spell.isFocusSpell ?? false,
        }));
        result.push({
            name: entry.name,
            tradition: entry.tradition ?? "",
            category: entry.category ?? entry.system?.prepared?.value ?? "",
            dc: entry.statistic?.dc?.value ?? 0,
            attack: entry.statistic?.check?.mod ?? 0,
            spells,
        });
    }
    return result;
}

function abilities(actor) {
    const withActions = [...actor.itemTypes.action, ...actor.itemTypes.feat]
        .filter((item) => ["action", "reaction", "free"].includes(item.system.actionType?.value));
    return withActions.map((item) => ({
        name: item.name,
        actionType: item.system.actionType.value,
        actions: item.system.actions?.value ?? null,
        traits: item.system.traits?.value ?? [],
        trigger: text(item.system.trigger?.value ?? ""),
        frequency: item.system.frequency ? `${item.system.frequency.max}/${item.system.frequency.per}` : "",
        text: text(item.system.description?.value),
    }));
}

function speeds(actor) {
    const speed = actor.system.attributes?.speed ?? actor.system.movement?.speeds?.land ?? {};
    const others = actor.system.attributes?.speed?.otherSpeeds ?? [];
    return [{ type: "land", feet: speed.total ?? speed.value ?? 0 },
            ...others.map((other) => ({ type: other.type, feet: other.total ?? other.value ?? 0 }))];
}

async function exportPregen(actor) {
    const skills = Object.values(actor.skills ?? {});
    return {
        key: slug(actor.name),
        name: baseName(actor.name),
        level: actor.level,
        ancestry: actor.ancestry?.name ?? "",
        heritage: actor.heritage?.name ?? "",
        background: actor.background?.name ?? "",
        className: actor.class?.name ?? "",
        size: actor.size ?? "med",
        traits: actor.system.traits?.value ?? [],
        attributes: Object.fromEntries(Object.entries(actor.abilities ?? actor.system.abilities ?? {})
            .map(([key, value]) => [key, value.mod])),
        armorClass: actor.armorClass?.value ?? 0,
        shieldBonus: actor.heldShield?.acBonus ?? 0,
        fortitude: actor.saves?.fortitude?.mod ?? 0,
        reflex: actor.saves?.reflex?.mod ?? 0,
        will: actor.saves?.will?.mod ?? 0,
        perception: actor.perception?.mod ?? 0,
        senses: (actor.system.perception?.senses ?? []).map((s) => s.label ?? s.type),
        hitPoints: actor.hitPoints?.max ?? actor.system.attributes?.hp?.max ?? 0,
        speeds: speeds(actor),
        languages: actor.system.details?.languages?.value ?? [],
        skills: skills.filter((s) => !s.lore).map((s) => ({ name: s.label, modifier: s.mod })),
        lores: skills.filter((s) => s.lore).map((s) => ({ name: s.label, modifier: s.mod })),
        classDC: actor.classDC?.dc?.value ?? 0,
        strikes: await strikes(actor),
        spellcasting: await spellcasting(actor),
        abilities: abilities(actor),
        feats: names(actor.itemTypes.feat.filter((f) => f.category !== "classfeature")),
        classFeatures: names(actor.itemTypes.feat.filter((f) => f.category === "classfeature")),
        items: names(actor.inventory?.contents ?? []),
    };
}

const actors = await pack.getDocuments();
const pregens = [];
for (const actor of actors.filter((a) => a.type === "character")) {
    try {
        pregens.push(await exportPregen(actor));
    } catch (error) {
        console.error(`Turnkeeper export: skipped ${actor.name}`, error);
        ui.notifications.warn(`Skipped ${actor.name}; see the console.`);
    }
}
pregens.sort((a, b) => a.key.localeCompare(b.key) || a.level - b.level);
const data = { system: game.system.id, version: game.system.version, exportedAt: new Date().toISOString(), pregens };
const save = foundry.utils.saveDataToFile ?? saveDataToFile;
save(JSON.stringify(data, null, 1), "application/json", `${game.system.id}-pregens.json`);
ui.notifications.info(`Exported ${pregens.length} pregens to ${game.system.id}-pregens.json.`);

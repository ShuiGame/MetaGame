module hello_world::hero {
    use sui::object::{Self, ID, UID};
    use std::option::{Self, Option};

    /// Our hero!
    struct Hero has key, store {
        id: UID,
        /// Hit points. If they go to zero, the hero can't do anything
        hp: u64,
        /// Experience of the hero. Begins at zero
        experience: u64,
        /// The hero's minimal inventory
        sword: Option<Sword>,
        /// An ID of the game user is playing
        game_id: ID,
    }

    /// The hero's trusty sword
    struct Sword has store {
        id:UID,
        /// Constant set at creation. Acts as a multiplier on sword's strength.
        /// Swords with high magic are rarer (because they cost more).
        magic: u64,
        /// Sword grows in strength as we use it
        strength: u64,
        /// An ID of the game
        game_id: ID,
    }

    public fun equip_sword(hero: &mut Hero, new_sword: Sword): Option<Sword> {
        option::swap_or_fill(&mut hero.sword, new_sword)
    }

    public fun remove_sword(hero: &mut Hero): Sword {
        assert!(option::is_some(&hero.sword), 3);
        option::extract(&mut hero.sword)
    }

    public fun delete_hero_for_testing(hero: Hero) {
        let Hero { id, hp: _, experience: _, sword, game_id: _ } = hero;
        object::delete(id);
        let sword = option::destroy_some(sword);
        let Sword { id, magic: _, strength: _, game_id: _ } = sword;
        object::delete(id);
    }
}
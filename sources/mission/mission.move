module shui_module::mission {
    use sui::object::{UID};
    use sui::event;
    use sui::table::{Self, Table};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::object::{Self, ID};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use std::string::{String, utf8};
    use sui::package;
    use sui::pay;
    use sui::clock::{Clock};
    use std::vector;
    use shui_module::metaIdentity::{Self, MetaIdentity};
    use std::debug::print;
    use sui::display;
    use shui_module::tree_of_life::{Self};
    use sui::linked_table::{Self, LinkedTable};
    use std::option::{Self};
    friend shui_module::tree_of_life;
    friend shui_module::airdrop;

    const ERR_MISSION_EXIST:u64 = 0x01;
    const ERR_NO_PERMISSION:u64 = 0x02;
    const ERR_META_RECORDS_NOT_EXIST:u64 = 0x03;
    const ERR_MISSION_NOT_EXIST:u64 = 0x04;
    const ERR_IS_ALREADY_CLAIMED:u64 = 0x05;
    const ERR_PROGRESS_NOT_REACH:u64 = 0x06;

    struct MissionGlobal has key {
        id: UID,

        // missionName -> MissionRecord
        mission_records: LinkedTable<String, MissionInfo>,
    }

    struct MissionInfo has store {
        name:String,
        desc:String,
        goal_process:u64,

        // metaId -> Record
        missions: Table<u64, UserRecord>,
        deadline:u64,
        reward:String
    }

    struct UserRecord has store, drop {
        name:String,
        metaId:u64,
        current_process:u64,
        is_claimed:bool
    }

    fun init(ctx: &mut TxContext) {
        let global = MissionGlobal {
            id: object::new(ctx),
            mission_records: linked_table::new<String, MissionInfo>(ctx),
        };
        transfer::share_object(global);
    }

    #[test_only]
    public fun init_for_test(ctx: &mut TxContext) {
        let global = MissionGlobal {
            id: object::new(ctx),
            mission_records: linked_table::new<String, MissionInfo>(ctx),
        };
        transfer::share_object(global);
    }

    public entry fun query_mission_list(global: &MissionGlobal, meta:&mut MetaIdentity) : String {
        let table = &global.mission_records;
        let key:&option::Option<String> = linked_table::front(table);
        let next:&option::Option<String> = linked_table::next(table, *option::borrow(key));
        while (option::is_some(next)) {
            let key_value = *option::borrow(next);
            let val_str:&MissionInfo = linked_table::borrow(table, key_value);
            next = linked_table::next(table, key_value);
        };
        utf8(b"MissionInfo records")
    }

    public entry fun claim_mission(global: &mut MissionGlobal, mission:String, meta:&mut MetaIdentity) {
        let mission_records = &mut global.mission_records;
        assert!(linked_table::contains(mission_records, mission), ERR_MISSION_NOT_EXIST);
        let mission_info = linked_table::borrow_mut(mission_records, mission);
        let metaId = metaIdentity::get_meta_id(meta);
        assert!(table::contains(&mission_info.missions, metaId), ERR_META_RECORDS_NOT_EXIST);
        let user_record = table::borrow_mut(&mut mission_info.missions, metaId);
        assert!(!user_record.is_claimed, ERR_IS_ALREADY_CLAIMED);
        assert!(user_record.current_process >= mission_info.goal_process, ERR_PROGRESS_NOT_REACH);
        let record = mission_info.reward;
        // todo: send item

        user_record.is_claimed = true;
    }   

    public(friend) fun add_process(global: &mut MissionGlobal, mission:String, meta:&MetaIdentity) {
        let mission_records = &mut global.mission_records;
        assert!(linked_table::contains(mission_records, mission), ERR_MISSION_NOT_EXIST);
        let mission_info = linked_table::borrow_mut(mission_records, mission);
        let metaId = metaIdentity::get_meta_id(meta);
        if (!table::contains(&mission_info.missions, metaId)) {
            let new_record = UserRecord {
                name:mission,
                metaId:metaId,
                current_process:1,
                is_claimed:false
            };
            table::add(&mut mission_info.missions, metaId, new_record);
        } else {
            let user_record = table::borrow_mut(&mut mission_info.missions, metaId);
            user_record.current_process = user_record.current_process + 1;
        };
    }

    public fun init_missions(global: &mut MissionGlobal, ctx:&mut TxContext) {
        // init all missions here, update with latest version
        // mission1: finish 3 water down
        let mission1_name = utf8(b"water down");
        let mission1 = MissionInfo {
            name:mission1_name,
            desc:utf8(b"water down 3 times"),
            goal_process:3,
            missions: table::new<u64, UserRecord>(ctx),
            deadline:0,
            reward:utf8(b"anything")
        };
        assert!(!linked_table::contains(&global.mission_records, mission1_name), ERR_MISSION_EXIST);
        linked_table::push_back(&mut global.mission_records, mission1_name, mission1);

        // mission1: swap any water element
        let mission2_name = utf8(b"swap water element");
        let mission2 = MissionInfo {
            name:mission2_name,
            desc:utf8(b"swap fragments into any water element"),
            goal_process:1,
            missions: table::new<u64, UserRecord>(ctx),
            deadline:0,
            reward:utf8(b"anything")
        };
        assert!(!linked_table::contains(&global.mission_records, mission2_name), ERR_MISSION_EXIST);
        linked_table::push_back(&mut global.mission_records, mission2_name, mission2);

        // mission1: swap any water element
        let mission3_name = utf8(b"claim airdrop");
        let mission3 = MissionInfo {
            name:mission2_name,
            desc:utf8(b"claim airdrop once"),
            goal_process:1,
            missions: table::new<u64, UserRecord>(ctx),
            deadline:0,
            reward:utf8(b"anything")
        };
        assert!(!linked_table::contains(&global.mission_records, mission3_name), ERR_MISSION_EXIST);
        linked_table::push_back(&mut global.mission_records, mission3_name, mission3);
    }

    public entry fun delete_mission(global: &mut MissionGlobal, mission:String, clock:&Clock, ctx:&mut TxContext) {
        assert!(tx_context::sender(ctx) == @account, ERR_NO_PERMISSION);
        assert!(linked_table::contains(&global.mission_records, mission), ERR_MISSION_EXIST);
        let mission_info = linked_table::remove(&mut global.mission_records, mission);
        let MissionInfo {name, desc, goal_process, missions, deadline, reward} = mission_info; 
        table::drop(missions);
    }
}
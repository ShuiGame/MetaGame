
module shui_module::items {
    use sui::bag::{Self};
    use sui::linked_table::{Self, LinkedTable};
    use sui::object::{Self, UID};
    use std::vector::{Self};
    use std::string;
    use sui::tx_context::{TxContext};
    use std::option::{Self};

    friend shui_module::metaIdentity;
    friend shui_module::tree_of_life;

    const ERR_ITEMS_VEC_NOT_EXIST:u64 = 0x001;
    const ERR_ITEMS_NOT_EXIST:u64 = 0x002;
    const ERR_ITEMS_NOT_ENOUGH:u64 = 0x003;

    struct Items has key, store {
        id:UID,

        // store all objects: name -> vector<T>
        bags:bag::Bag,

        // store nums of objects for print: name -> num
        link_table:LinkedTable<string::String, u64>
    }

    public(friend) fun new(ctx:&mut TxContext): Items {
        Items {
            id: object::new(ctx),
            bags:bag::new(ctx),
            link_table:linked_table::new<string::String, u64>(ctx)
        }
    }

    public(friend) fun destroy_empty(items: Items) {
        let Items {id, bags:bags, link_table} = items;
        object::delete(id);
        linked_table::drop(link_table);
        bag::destroy_empty(bags);
    }

    public(friend) fun store_item<T:store>(items: &mut Items, name:string::String, item:T) {
        if (bag::contains(&mut items.bags, name)) {
            let vec = bag::borrow_mut(&mut items.bags, name);
            vector::push_back(vec, item);
            let len = vector::length(vec);
            set_items_num(&mut items.link_table, name, len);
        } else {
            let vec = vector::empty<T>();
            vector::push_back(&mut vec, item);
            bag::add(&mut items.bags, name, vec);
            set_items_num(&mut items.link_table, name, 1);
        }
    }

    public(friend) fun store_items<T:store>(items: &mut Items, name:string::String, item_arr: vector<T>) {
        if (bag::contains(&mut items.bags, name)) {
            let vec = bag::borrow_mut(&mut items.bags, name);
            let (i, len) = (0u64, vector::length(&item_arr));
            while (i < len) {
                let item:T = vector::pop_back(&mut item_arr);
                vector::push_back(vec, item);
                i = i + 1
            };
            let len = vector::length(vec);
            set_items_num(&mut items.link_table, name, len);
        } else {
            let vec = vector::empty<T>();
            let (i, len) = (0u64, vector::length(&item_arr));
            while (i < len) {
                let item:T = vector::pop_back(&mut item_arr);
                vector::push_back(&mut vec, item);
                i = i + 1
            };
            bag::add(&mut items.bags, name, vec);
            set_items_num(&mut items.link_table, name, len);
        };
        vector::destroy_empty(item_arr);
    }

    public(friend) fun extract_item<T:store>(items: &mut Items, name:string::String): T {
        assert!(bag::contains(&items.bags, name), ERR_ITEMS_VEC_NOT_EXIST);
        let vec:&mut vector<T> = bag::borrow_mut(&mut items.bags, name);
        assert!(vector::length(vec) > 0, ERR_ITEMS_NOT_EXIST);
        let item = vector::pop_back(vec);
        let len = vector::length(vec);
        set_items_num(&mut items.link_table, name, len);
        item
    }

    public(friend) fun extract_items<T:store>(items: &mut Items, name:string::String, num:u64): vector<T> {
        assert!(bag::contains(&items.bags, name), ERR_ITEMS_VEC_NOT_EXIST);
        let vec:&mut vector<T> = bag::borrow_mut(&mut items.bags, name);
        assert!(vector::length(vec) >= num, ERR_ITEMS_NOT_ENOUGH);
        let extra_vec = vector::empty();
        let i = 0u64;
        while (i < num) {
            let item:T = vector::pop_back(vec);
            vector::push_back(&mut extra_vec, item);
            i = i + 1
        };
        let len = vector::length(vec);
        set_items_num(&mut items.link_table, name, len);
        extra_vec
    }

    fun set_items_num(linked_table: &mut linked_table::LinkedTable<string::String, u64>, name:string::String, num:u64) {
        if (linked_table::contains(linked_table, name)) {
            let num_m = linked_table::borrow_mut(linked_table, name);
            *num_m = num;
        } else {
            linked_table::push_back(linked_table, name, num);
        }
    }

    public entry fun get_items_info(table: &linked_table::LinkedTable<string::String, u64>):string::String {
        if (linked_table::is_empty(table)) {
            return string::utf8(b"none")
        };
        let key:&option::Option<string::String> = linked_table::front(table);
        let next:&option::Option<string::String> = linked_table::next(table, *option::borrow(key));
        while (option::is_some(next)) {
            next = linked_table::next(table, *option::borrow(key));
        };
        string::utf8(b"something")
    }
}
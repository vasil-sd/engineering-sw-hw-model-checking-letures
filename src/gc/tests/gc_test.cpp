#include "gc.h"

#include <iostream>

#include <cstddef>

#include <vector>

static const size_t pool_size = 65536;

static char mempool[pool_size];

static Memory mem{mempool, &mempool[pool_size]};

void Test() {

    struct Something {
        int a;
        struct Something* next;
    };

    std::cout << "Initial: " << std::endl << mem << std::endl;

    auto alloc = mem.allocator<Something>();
    auto gc = Gc{mem};

    auto* obj1 = alloc.allocate(1);
    auto* obj2 = alloc.allocate(1);
    auto* obj3 = alloc.allocate(1);

    std::cout << "Created 3 objects: " << std::endl << mem << std::endl;

    gc.RegisterRootObject(obj1);
    obj1->next = gc.LinkToObj(obj1, obj2);
    obj2->next = gc.LinkToObj(obj2, obj3);
    obj3->next = gc.LinkToObj(obj3, obj1);

    std::cout << "After objects linked: " << std::endl << mem << std::endl;

    gc.GcInit();

    std::cout << "After gc init: " << std::endl << mem << std::endl;

    while(gc.GcMarkStep()) {
        std::cout << "After gc mark step: " << std::endl << mem << std::endl;
    }

    gc.GcCollect();
    std::cout << "After gc collect: " << std::endl << mem << std::endl;

    gc.UnregisterRootObject(obj1);

    std::cout << "After gc unregister root: " << std::endl << mem << std::endl;

    gc.FullGc();
    std::cout << "After full gc: " << std::endl << mem << std::endl;
}

int main(int argc, char** argv) {
    Test();
    return 0;
}

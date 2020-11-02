#include "memory.h"

#include <iostream>

#include <cstddef>

#include <vector>

static const size_t pool_size = 65536;

static char mempool[pool_size];

static Memory mem{mempool, &mempool[pool_size]};

void Test() {

    struct Something {
        int a;
        int b;
    };

    std::cout << "Initial: " << std::endl << mem << std::endl;

    auto alloc = mem.allocator<Something>();

    {
        std::vector<Something, decltype(alloc)> vec(alloc);

        std::cout << "vector created: " << std::endl << mem << std::endl;

        for(int a=0; a<100; ++a) {
            vec.emplace_back(Something{a,a});
        }

        std::cout << "vector populated: " << std::endl << mem << std::endl;

        for(int a=0; a<70; ++a) {
            vec.pop_back();
        }

        std::cout << "some elements are removed from vector : " << std::endl << mem << std::endl;

        vec.shrink_to_fit();

        std::cout << "vector was shrinked: " << std::endl << mem << std::endl;

    }

    std::cout << "vector destroyed: " << std::endl << mem << std::endl;

}

int main(int argc, char** argv) {
    Test();
    return 0;
}

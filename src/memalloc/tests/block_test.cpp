#include "block.h"

#include <iostream>

void Test() {
    char *mem = new char[512];
    AddrSpace aspace{mem, &mem[512]};

    Block& b1 = Block::MakeAtAddress(aspace.lowest(), Size{Block::BlockHeaderSize + 16});
    Block& b2 = Block::MakeAtAddress(b1.NextBlockAddress(), Size{Block::BlockHeaderSize + 32});

    b1.InsertAbove(b2);

    b1.ForAll([](const Block& b){
        std::cout << b << std::endl;
        return true;
    });
}

int main(int argc, char** argv) {
    Test();
    return 0;
}
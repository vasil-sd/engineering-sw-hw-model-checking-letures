#include "double_linked_list.h"

#include <cassert>

void Test() {
    class Something : public DlElt<Something> {
    public:
        Something(int val) : value_{val} {}
        bool operator==(const Something& rhs) {
            return value_ == rhs.value_;
        }
    private:
        int value_;
    };

    Something s1{1};

    {
        Something s2{2};

        s2.InsertAbove(s1); // s1 -> s2

        // check properly linking
        assert(!s2.HasNext());
        assert(!s1.HasPrev());
        assert(s2.HasPrev());
        assert(s1.HasNext());

        assert(s1.next() == s2);
        assert(s2.prev() == s1);

        {
            Something s3{3};

            s3.InsertAbove(s1); // s1 -> s3 -> s2

            // check properly linking
            assert(!s2.HasNext());
            assert(!s1.HasPrev());
            assert(s2.HasPrev());
            assert(s1.HasNext());
            assert(s3.HasPrev());
            assert(s3.HasNext());

            assert(s1.next() == s3);
            assert(s2.prev() == s3);
            assert(s3.prev() == s1);
            assert(s3.next() == s2);

            {
                Something s4{4};

                s4.InsertBelow(s1); // s4 -> s1 -> s3 -> s2

                assert(s1.HasPrev());
                assert(!s4.HasPrev());
                assert(s4.HasNext());

                assert(s4.next() == s1);
                assert(s1.prev() == s4);
                assert(s1.next() == s3);
                assert(s2.prev() == s3);
                assert(s3.prev() == s1);
                assert(s3.next() == s2);

            } // here s4 is destructed and automatically unlinked

            assert(s1.next() == s3);
            assert(s2.prev() == s3);
            assert(s3.prev() == s1);
            assert(s3.next() == s2);

        } // here s3 is destructed and automatically unlinked

        assert(s1.next() == s2);
        assert(s2.prev() == s1);

    } // here s2 is destructed and automatically unlinked

    assert(!s1.HasNext());
    assert(!s1.HasPrev());
}

int main(int argc, char** argv) {
    Test();
    return 0;
}

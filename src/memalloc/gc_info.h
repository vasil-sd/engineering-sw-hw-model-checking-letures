#pragma once

struct GcInfo {
    bool marked;
    bool to_be_checked;
    bool root;
};

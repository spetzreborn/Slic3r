#include <admesh/stl.h>
#include <vector>

extern "C" {
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"
}

class TriangleMesh
{
    public:
    TriangleMesh();
    ~TriangleMesh();
    void ReadSTLFile(char* input_file);
    void ReadFromPerl(SV* vertices, SV* facets);
    void Repair();
    void WriteOBJFile(char* output_file);
    AV* ToPerl();
    SV* Slice(std::vector<double>* z);
    private:
    stl_file stl;
};



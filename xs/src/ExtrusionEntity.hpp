#ifndef slic3r_ExtrusionEntity_hpp_
#define slic3r_ExtrusionEntity_hpp_

#include <myinit.h>
#include "Polygon.hpp"
#include "Polyline.hpp"

namespace Slic3r {

class ExPolygonCollection;
class ExtrusionEntityCollection;

enum ExtrusionRole {
    erPerimeter,
    erExternalPerimeter,
    erOverhangPerimeter,
    erContourInternalPerimeter,
    erFill,
    erSolidFill,
    erTopSolidFill,
    erBrige,
    erInternalBridge,
    erSkirt,
    erSupportMaterial,
    erGapFill,
};

class ExtrusionEntity
{
    public:
    virtual ExtrusionEntity* clone() const = 0;
    virtual ~ExtrusionEntity() {};
    ExtrusionRole role;
    double mm3_per_mm;  // mm^3 of plastic per mm of linear head motion
    virtual void reverse() = 0;
    virtual Point* first_point() const = 0;
    virtual Point* last_point() const = 0;
    bool is_perimeter() const;
    bool is_fill() const;
    bool is_bridge() const;
};

typedef std::vector<ExtrusionEntity*> ExtrusionEntitiesPtr;

class ExtrusionPath : public ExtrusionEntity
{
    public:
    ExtrusionPath* clone() const;
    Polyline polyline;
    void reverse();
    Point* first_point() const;
    Point* last_point() const;
    ExtrusionEntityCollection* intersect_expolygons(ExPolygonCollection* collection) const;
    ExtrusionEntityCollection* subtract_expolygons(ExPolygonCollection* collection) const;
    void clip_end(double distance);
    void simplify(double tolerance);
    double length() const;
    private:
    ExtrusionEntityCollection* _inflate_collection(const Polylines &polylines) const;
};

class ExtrusionLoop : public ExtrusionEntity
{
    public:
    ExtrusionLoop* clone() const;
    Polygon polygon;
    ExtrusionPath* split_at_index(int index) const;
    ExtrusionPath* split_at_first_point() const;
    bool make_counter_clockwise();
    void reverse();
    Point* first_point() const;
    Point* last_point() const;
};

}

#endif

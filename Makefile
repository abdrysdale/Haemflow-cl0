# Configuration

FC := gfortran
LD := $(FC)
RM := rm -f
CFLAGS= -Wall -Wextra -O2
DEBUGFLAGS=-g
OPTFLAGS=-O2

# Source files
SRCS := src/closed_loop_lumped.f90 \
		src/cust_fns.f90 \
		src/data_types.f90 \
		src/elastance.f90 \
		src/funcs.f90 \
		src/inputs.f90 \
		src/kind_parameter.f90 \
		src/thermoregulation.f90 \
		app/main.f90
PROG := closed_loop_lumped
LIB := $(PROG).so
OBJS := $(addsuffix .o, $(SRCS))

.PHONY: all clean debug
all: $(PROG)

$(PROG): $(OBJS)
	$(LD) -o $@ $^

$(OBJS): %.o: %
	$(FC) $(CFLAGS) -c -o $@ $<

debug: CFLAGS+=$(DEBUGFLAGS)
debug: $(PROG)
debug: $(LIB)

opt: CFLAGS+=$(OPTFLAGS)
opt: $(PROG)
opt: $(LIB)

$(LIB): $(OBJS)
	$(FC) $(CFLAGS) -c $(SRCS)
	$(FC) $(CFLAGS) -m64 -shared -o $(LIB) $(OBJS)

lib: $(LIB)

# Defines module interdependencies
main.mod := src/kind_parameter.f90.o \
	src/data_types.f90.o \
	src/inputs.f90.o \
	src/funcs.f90.o
closed_loop_lumped.mod := src/funcs.f90.o \
	src/data_types.f90.o \
	src/kind_parameter.f90.o
cust_fns.mod := src/kind_parameter.f90.o
data_types.mod := src/kind_parameter.f90.o
elastance.mod := src/kind_parameter.f90.o \
	src/data_types.f90.o
funcs.mod := src/kind_parameter.f90.o \
	src/data_types.f90.o \
	src/inputs.f90.o \
	src/cust_fns.f90.o \
	src/elastance.f90.o \
	src/thermoregulation.f90.o
inputs.mod := src/kind_parameter.f90.o \
	src/data_types.f90.o
thermoregulation.mod := src/kind_parameter.f90.o \
	src/data_types.f90.o
app/main.f90.o: $(main.mod)
src/closed_loop_lumped.f90.o: $(closed_loop_lumped.mod)
src/cust_fns.f90.o: $(cust_fns.mod)
src/data_types.f90.o: $(data_types.mod)
src/elastance.f90.o: $(elastance.mod)
src/funcs.f90.o: $(funcs.mod)
src/inputs.f90.o: $(inputs.mod)
src/thermoregulation.f90.o: $(thermoregulation.mod)

clean:
	$(RM) $(wildcard src/*.o) $(wildcard src/*.mod) $(PROG) $(wildcard src/*.so)

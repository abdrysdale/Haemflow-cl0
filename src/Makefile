# Configuration

FC := gfortran
LD := $(FC)
RM := rm -f

# Source files
SRCS := src/closed_loop_lumped.f90 \
		src/cust_fns.f90 \
		src/data_types.f90 \
		src/elastance.f90 \
		src/funcs.f90 \
		src/inputs.f90 \
		src/kind_parameter.f90 \
		app/main.f90
PROG := closed_loop_lumped
OBJS := $(addsuffix .o, $(SRCS))
LIB := src/closed_loop_lumped.f90

.PHONY: all clean
all: $(PROG)

$(PROG): $(OBJS)
	$(LD) -o $@ $^

$(OBJS): %.o: %
	$(FC) -c -o $@ $<

lib: $(OBJS)
	$(FC) -c $(SRCS)
	$(FC) -m64 -shared $(LIB) -o $(PROG).so $(OBJS)

# Defines module interdependencies
app/main.mod := src/kind_parameter.f90.o \
	src/data_types.f90.o \
	src/inputs.f90.o \
	src/funcs.f90.o
src/closed_loop_lumped.mod := src/funcs.f90.o \
	src/data_types.f90.o \
	src/kind_parameter.f90.o
src/cust_fns.mod := src/kind_parameter.f90.o
src/data_types.mod := src/kind_parameter.f90.o
src/elastance.mod := src/kind_parameter.f90.o \
	src/data_types.f90.o
src/funcs.mod := src/kind_parameter.f90.o \
	src/data_types.f90.o \
	src/inputs.f90.o \
	src/cust_fns.f90.o \
	src/elastance.f90.o
src/inputs.mod := src/kind_parameter.f90.o \
	src/data_types.f90.o
app/main.f90.o: $(app/main.mod)
src/closed_loop_lumped.f90.o: $(src/closed_loop_lumped.mod)
src/cust_fns.f90.o: $(src/cust_fns.mod)
src/data_types.f90.o: $(src/data_types.mod)
src/elastance.f90.o: $(src/elastance.mod)
src/funcs.f90.o: $(src/funcs.mod)
src/inputs.f90.o: $(src/inputs.mod)

clean:
	$(RM) $(filter %.o, %(OBJS)) $(wildcard *.mod) $(PROG) $(wildcard *.so)

module data_types

    use kind_parameter
    implicit none

    private
    public chamber, chambers
    public arterial_system, arterial_network
    public valve, valve_system
    public heart_elastance

    ! Declares the type for each chamber
    type :: chamber
        real(dp) :: Emin ! Minimum elastance
        real(dp) :: Emax ! Maximum elastance
        real(dp) :: V0_1 ! Minimum volume
        real(dp) :: V0_2 ! Maximum volume
    end type chamber

    ! Declares the type for all 4 heart chambers
    type :: chambers
        type (chamber) :: LV ! Left ventrical
        type (chamber) :: LA ! Left atrium
        type (chamber) :: RV ! Right ventrical
        type (chamber) :: RA ! Right atrium
     end type chambers

    ! Declare systemic/pulmonary system
    type :: arterial_system
        real(dp) :: Ras ! Aortic (or Pulmonary Artery) Sinus Resistance
        real(dp) :: Rat ! Artery Resistance
        real(dp) :: Rar ! Arterioles Resistance
        real(dp) :: Rcp ! Capillary Resistance
        real(dp) :: Rvn ! Vein Resistance
        real(dp) :: Cas ! Aortic Sinus (or Pulmonary Artery) Compliance
        real(dp) :: Cat ! Artery Compliance
        real(dp) :: Cvn ! Vein Compliance
        real(dp) :: Las ! Aortic Sinus (or Pulmonary Artery) Inductance
        real(dp) :: Lat ! Artery Inductance
     end type arterial_system

    ! Declares the complete network
    type :: arterial_network
        type (arterial_system) :: sys   ! Systemic system (arterial and venous)
        type (arterial_system) :: pulm  ! Pulmonary system (arterial and venous)
        real(dp) :: rho
     end type arterial_network

    ! Declares the valve type
    type :: valve
        real(dp) :: Leff    ! Effective inductance of the valve.
        real(dp) :: Aeffmin ! Minimum effective area of the valve.
        real(dp) :: Aeffmax ! Maximum effective area of the valve.
        real(dp) :: Kvc     ! Valve closing parameter
        real(dp) :: Kvo     ! Valve opening parameter
     end type valve

    ! Declares a system of valves
    type :: valve_system
        type (valve) :: AV ! Aortic
        type (valve) :: MV ! Mitral
        type (valve) :: PV ! Pulmonary
        type (valve) :: TV ! Tricuspid
     end type valve_system

    ! Declares the heart elastance type
    type :: heart_elastance
        real(dp), allocatable :: ELV(:) ! Elastance curve for the left ventrical
        real(dp), allocatable :: ELA(:) ! Elastance curve for the left atrium
        real(dp), allocatable :: ERV(:) ! Elastance curve for the right ventrical
        real(dp), allocatable :: ERA(:) ! Elastance curve for the right atrium
     end type heart_elastance

end module data_types

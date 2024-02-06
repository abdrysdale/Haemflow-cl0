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
        real(dp) :: Emin
        real(dp) :: Emax
        real(dp) :: V0_1
        real(dp) :: V0_2
    end type chamber

    ! Declares the type for all 4 heart chambers
    type :: chambers
        type (chamber) :: LV
        type (chamber) :: LA
        type (chamber) :: RV
        type (chamber) :: RA
     end type chambers

    ! Declare artery system
    type :: arterial_system
        real(dp) :: Ras
        real(dp) :: Rat
        real(dp) :: Rar
        real(dp) :: Rcp
        real(dp) :: Rvn
        real(dp) :: Cas
        real(dp) :: Cat
        real(dp) :: Cvn
        real(dp) :: Las
        real(dp) :: Lat
     end type arterial_system

    ! Declares the complete network
    type :: arterial_network
        type (arterial_system) :: sys
        type (arterial_system) :: pulm
        real(dp) :: rho
     end type arterial_network

    ! Declares the valve type
    type :: valve
        real(dp) :: Leff ! cm
        real(dp) :: Aeffmin
        real(dp) :: Aeffmax
        real(dp) :: Kvc
        real(dp) :: Kvo
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
        real(dp), allocatable :: ELV(:)
        real(dp), allocatable :: ELA(:)
        real(dp), allocatable :: ERV(:)
        real(dp), allocatable :: ERA(:)
     end type heart_elastance

end module data_types

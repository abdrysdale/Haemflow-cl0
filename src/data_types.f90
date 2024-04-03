module data_types

    use kind_parameter
    implicit none

    private
    public chamber, chambers
    public arterial_system, arterial_network
    public valve, valve_system
    public heart_elastance
    public thermal_system

    ! Declares the type for each chamber
    type :: chamber
        real(dp) :: Emin ! Minimum elastance
        real(dp) :: Emax ! Maximum elastance
        real(dp) :: V0_1 ! Minimum volume
        real(dp) :: V0_2 ! Maximum volume
    end type chamber

    ! Declares the type for all 4 heart chambers
    type :: chambers
        type (chamber) :: LV ! Left ventricle
        type (chamber) :: LA ! Left atrium
        type (chamber) :: RV ! Right ventricle
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
        real(dp), allocatable :: ELV(:) ! Elastance curve for the left ventricle
        real(dp), allocatable :: ELA(:) ! Elastance curve for the left atrium
        real(dp), allocatable :: ERV(:) ! Elastance curve for the right ventricle
        real(dp), allocatable :: ERA(:) ! Elastance curve for the right atrium
     end type heart_elastance

     ! Declares the system of thermal parameters
     type :: thermal_system
        real(dp) :: q_sk_basal  ! Basal skin blood flow under neutral conditions (Kg / m^2 / hr)
        real(dp) :: k_dil       ! Coefficient of vasodilation
        real(dp) :: T_cr        ! Core temperature
        real(dp) :: T_cr_ref    ! Core temperature at neutral conditions
        real(dp) :: k_con       ! Coefficient of vasoconstriction
        real(dp) :: T_sk        ! Skin temperature
        real(dp) :: T_sk_ref    ! Skin temperature at neutral condtions
     end type thermal_system

end module data_types

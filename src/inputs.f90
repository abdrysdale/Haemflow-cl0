module inputs
    ! Heart Input Declaration
    use kind_parameter
    use data_types
    implicit none

    private
    public heart_input, artery_input

contains

    ! Gets the heart input
    subroutine heart_input(LV, LA, RV, RA, T, scale_EmaxLV, scale_EmaxRV, scale_Emax)

        ! Defines initial variables
        real(dp), intent(in) :: T
        real(dp), intent(in) :: scale_EmaxLV
        real(dp), intent(in) :: scale_EmaxRV
        real(dp), intent(in) :: scale_Emax

        type (chamber), intent(inout) :: LV
        type (chamber), intent(inout) :: LA
        type (chamber), intent(inout) :: RV
        type (chamber), intent(inout) :: RA

        ! Left Ventricle
        LV%Emax = LV%Emax * scale_EmaxLV
        LV%tau1 = LV%tau1 * T
        LV%tau2 = LV%tau2 * T

        ! Left Atrium
        LA%Emax = LA%Emax * scale_Emax
        LA%tau1 = LA%tau1 * T
        LA%tau2 = LA%tau2 * T
        LA%onset = LA%onset * T

        ! Right Ventricle
        RV%Emax = RV%Emax * scale_EmaxRV
        RV%tau1 = RV%tau1 * T
        RV%tau2 = RV%tau2 * T

        ! Right Atrium
        RA%Emax = RA%Emax * scale_Emax
        RA%tau1 = RA%tau1 * T
        RA%tau2 = RA%tau2 * T
        RA%onset = RA%onset * T

    end subroutine heart_input

    ! Gets the artery input
    subroutine artery_input(sys, pulm, scale_Rsys, scale_Csys, scale_Rpulm, scale_Cpulm)

        ! Declare inputs
        type (arterial_system), intent(inout) :: sys, pulm
        real(dp), intent(in) :: scale_Rsys, scale_Csys, scale_Rpulm, scale_Cpulm

        ! Systemic system
        sys%Ras = sys%Ras * scale_Rsys
        sys%Rat = sys%Rat * scale_Rsys
        sys%Rar = sys%Rar * scale_Rsys
        sys%Rcp = sys%Rcp * scale_Rsys

        sys%Cas = sys%Cas * scale_Csys
        sys%Cat = sys%Cat * scale_Csys
        sys%Cvn = sys%Cvn * scale_Csys
        
        ! Pulmonary system
        pulm%Ras = pulm%Ras * scale_Rpulm
        pulm%Rat = pulm%Rat * scale_Rpulm
        pulm%Rar = pulm%Rar * scale_Rpulm
        pulm%Rcp = pulm%Rcp * scale_Rpulm

        pulm%Cas = pulm%Cas * scale_Cpulm
        pulm%Cat = pulm%Cat * scale_Cpulm
        pulm%Cvn = pulm%Cvn * scale_Cpulm

    end subroutine artery_input
end module inputs

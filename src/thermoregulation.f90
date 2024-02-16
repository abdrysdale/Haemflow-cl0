module thermoregulation
  use kind_parameter
  use data_types

contains

   pure function calc_resistance_index(&
    q_sk_basal, &
    k_dil, T_cr, T_cr_ref, &
    k_con, T_sk, T_sk_ref) result(lambda)
    ! Calculates the resistance index for the skin based on Gagge's two node model

    ! Declares variables
    real(dp), intent(in) :: q_sk_basal  ! Basal skin flow at neutral conditions
    real(dp), intent(in) :: k_dil       ! Coefficient of vasodilation
    real(dp), intent(in) :: T_cr        ! Core temperature
    real(dp), intent(in) :: T_cr_ref    ! Core temperature at neutral conditions
    real(dp), intent(in) :: k_con       ! Coefficient of vasoconstriction
    real(dp), intent(in) :: T_sk        ! Skin temperature
    real(dp), intent(in) :: T_sk_ref    ! Skin temperature at neutral condtions

    real(dp) :: wsig_cr                 ! Warm signal - core.
    real(dp) :: csig_sk                 ! Cold signal - skin.
    real(dp) :: lambda                  ! Resistance index.

    wsig_cr = max(0.0_dp, T_cr - T_cr_ref)
    csig_sk = max(0.0_dp, T_sk_ref - T_sk)

    lambda = (q_sk_basal + k_dil * wsig_cr) / (q_sk_basal * (1 + k_con * csig_sk))

  end function calc_resistance_index

  pure function calc_r_sk(r_sk, therm) result(new_r_sk)
    ! Updates the skin resistance based on Gagge's two-node thermal model.

    ! Declares variables
    real(dp), intent(in) :: r_sk                ! Skin resistance
    type (thermal_system), intent(in) :: therm  ! Thermal system coefficients

    real(dp) :: lambda                  ! Resistance index
    real(dp) :: new_r_sk                ! New skin resistance

    ! Avoids diving by 0
    if (abs(therm%q_sk_basal) > 1e-30) then
       lambda = calc_resistance_index(&
            therm%q_sk_basal, &         ! Basal Skin Blood Flow under neutral conditions
            therm%k_dil, therm%T_cr, therm%T_cr_ref, &
            therm%k_con, therm%T_sk, therm%T_sk_ref)
    else
       lambda = 1.0_dp
    end if


    new_r_sk = r_sk / lambda

  end function calc_r_sk
end module thermoregulation

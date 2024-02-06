module elastance

    use kind_parameter
    use data_types
    implicit none

    private
    public calc_elastance

contains

    elemental function mult(a, b) result(c)
        real(dp), intent(in) :: a
        real(dp), intent(in) :: b
        real(dp) :: c
        c = a * b
    end function

    elemental function calc_g1(g1_1) result(g1_2)
        real(dp), intent(in) :: g1_1
        real(dp) :: g1_2
        g1_2 = g1_1 / ( 1 + g1_1)
    end function calc_g1

    elemental function calc_g2(g2_1) result(g2_2)
        real(dp), intent(in) :: g2_1
        real(dp) :: g2_2
        g2_2 = 1 / ( 1 + g2_1)
    end function calc_g2

    ! Atria elastance activation functions taken from:
    ! J. D. Thomas, J. Zhou, N. Greenberg, G. Bibawy, P. M. McCarthy, and P. M. Vandervoort, 
    ! “Physical and physiological determinants of pulmonary venous flow: Numerical analysis,” 
    ! Amer. J. Physiol. Heart Circ. Physiol., vol. 272, no. 5, pp. H2453–H2465, 1997.
    elemental function atria_act(t, T1, T2) result(u_a)
      real(dp), intent(in) :: t
      real(dp), intent(in) :: T1
      real(dp), intent(in) :: T2
      real(dp) :: u_a
      real(dp), parameter :: pi=4.D0*datan(1.D0)

      if ( (T1 <= t) .and. (t <= T2) ) then
         u_a = 0.5 * (1 - cos((2*pi*(t - T1))/(T2 - T1)))
      else
         u_a = 0
      end if
    end function atria_act

    ! Ventrical elastance activation functions taken from:
    ! D. C. Chung, S. C. Niranjan, J. W. Clark, A. Bidani, W. E. Johnston, J. B. Zwischenberger, and D. L. Traber, 
    ! “A dynamic model of ventricular interaction and pericardial influence,”
    ! Amer. J. Physiol. Heart Circ. Physiol., vol. 272, no. 6, pp. H2942–H2962, Jun. 1, 1997.
    elemental function ventrical_act(t, T2, T3, T4) result(u_v)
      real(dp), intent(in) :: t
      real(dp), intent(in) :: T2
      real(dp), intent(in) :: T3
      real(dp), intent(in) :: T4
      real(dp) :: u_v
      real(dp), parameter :: pi=4.D0*datan(1.D0)

      if ( (T2 <= t) .and. (t < T3) ) then
         u_v = 0.5 * (1 - cos((pi*(t - T2))/(T3 - T2)))
      else if ( (T3 <= t) .and. (t <= T4) ) then
         u_v = 0.5 * (1 + cos((pi*(t - T3))/(T4 - T3)))
      else
         u_v = 0
      end if

    end function ventrical_act

    ! Calculates the elastance of the heart
    elemental function calc_elastance(cham, t, T1, T2, T3, T4, is_atria) result(E_out)

        ! Declares input variables
        type(chamber), intent(in) :: cham
        real(dp), intent(in) :: T1
        real(dp), intent(in) :: T2
        real(dp), intent(in) :: T3
        real(dp), intent(in) :: T4
        real(dp), intent(in) :: t
        logical, intent(in) :: is_atria

        ! Declares output variable
        real(dp) :: E_out

        ! Declares intermediate variables
        real(dp), parameter :: pi=4.D0*datan(1.D0)

        if (is_atria) then
           E_out = cham%Emin + (cham%Emax - cham%Emin) * atria_act(t, T1, T2)
        else
           E_out = cham%Emin + (cham%Emax - cham%Emin) * ventrical_act(t, T2, T3, T4)
        end if
    end function calc_elastance
end module elastance

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

    elemental function atria_act(t, T1, T2) result(u_a)
      real(dp), intent(in) :: t
      real(dp), intent(in) :: T1
      real(dp), intent(in) :: T2
      real(dp), intent(out) :: u_a

      if ( (T1 <= t) .and. (t <= T2) ) then
         u_a = 0.5 * (1 - cos((2*pi*(t - T1))/(T2 - T1)))
      else
         u_a = 0
      end if
    end function atria_act

    elemental function ventrical_act(t, T2, T3, T4) result(u_v)
      real(dp), intent(in) :: t
      real(dp), intent(in) :: T2
      real(dp), intent(in) :: T3
      real(dp), intent(in) :: T4
      real(dp), intent(out) :: u_v

      if ( (T2 <= t) .and. (t < T3) ) then
         u_v = 0.5 * (1 - cos((pi*(t - T2))/(T3 - T2)))
      else if ( (T3 <= t) .and. (t <= T4) ) then
         u_v = 0.5 * (1 + cos((pi*(t - T3))/(T4 - T3)))
      else
         u_v = 0
      end if

    end function ventrical_act

    ! Calculates the elastance of the heart
    pure function calc_elastance(LV, nstep, T, E_t) result(E_out)

        ! Declares input variables
        type(chamber), intent(in) :: LV
        integer, intent(in) :: nstep
        real(dp), intent(in) :: T
        real(dp), intent(in) :: E_t(nstep)

        ! Declares output variable
        real(dp), dimension(nstep) :: E_out

        ! Declares intermediate variables
        real(dp), dimension(nstep) :: E_tmp
        integer :: i, t_idx
        real(dp), dimension(nstep) :: q
        real(dp), dimension(nstep - 1) :: dt
        real(dp), dimension(nstep) :: v
        real(dp), dimension(nstep) :: g1_1 ! g1 in MATLAB
        real(dp), dimension(nstep) :: g2_1
        real(dp), dimension(nstep) :: g1_2 ! G1 in MATLAB
        real(dp), dimension(nstep) :: g2_2
        real(dp), dimension(nstep) :: g12_prod
        real(dp) :: k
        real(dp), dimension(nstep) :: p_tmp
        real(dp), dimension(nstep) :: p
        real(dp), parameter :: pi=4.D0*datan(1.D0)

        ! Initialise output
        E_out = 0

        ! Defines variables
        q = sin(2 * pi * E_t / ( 2 * T))
        do i = 1, nstep - 1
            dt(i) = E_t(i + 1) - E_t(i)
        end do
        v(1) = LV%V0_2
        v(2:) = LV%V0_2 - q(2:) * dt

        g1_1 = (E_t / (LV%tau1 * T)) ** LV%m1
        g2_1 = (E_t / (LV%tau2 * T)) ** LV%m2
        g1_2 = calc_g1(g1_1)
        g2_2 = calc_g2(g2_1)
        g12_prod = mult(g1_2, g2_2)
        k = (LV%Emax - LV%Emin) / maxval(g12_prod)

        E_tmp = (k * g12_prod) + LV%Emin
        p_tmp = mult(E_tmp, (v - LV%V0_1))
        p = mult(p_tmp, (1 - LV%Ks * q))

        t_idx = count(E_t <= T - LV%onset)
        if ( t_idx == nstep ) then
            E_out = E_tmp
        else
            E_out(1:nstep-t_idx) = E_tmp(t_idx+1:)
            E_out(1 + nstep-t_idx:) = E_tmp(:t_idx) 
        end if
    end function calc_elastance
end module elastance

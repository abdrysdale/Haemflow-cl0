program main
    
    use kind_parameter
    use cust_fns
    use data_types
    use inputs
    use elastance
    use funcs
    use ieee_arithmetic
    implicit none

    ! Declares initial variables
    integer :: nstep, ncycle, rk, i, icycle, k, io, nan_count, inf_count, offset
    real(dp) :: T, pini_sys, pini_pulm, h, t_val
    type (arterial_network) :: a_cof
    type (chambers) :: h_cof
    type (valve) :: AV, MV, PV, TV
    type (valve_system) :: v_cof
    real(dp), allocatable, dimension(:) :: ELV, ELA, ERV, ERA
    type (heart_elastance) :: elast, elast_half
    real(dp) :: current_sol(22)
    real(dp), allocatable :: sol(:, :)
    real(dp), allocatable :: h_pres(:, :) 
    real(dp), allocatable :: t_axis(:)
    real(dp), dimension(22) :: k1, k2, k3, k4
    character(len=50), dimension(22) :: headers
    real(dp) :: scale_Rsys, scale_Csys, scale_Rpulm, scale_Cpulm
    real(dp) :: scale_Emax, scale_EmaxLV, scale_EmaxRV
    real(dp) :: rho
    type (arterial_system) :: sys
    type (arterial_system) :: pulm
    type (chamber) :: LV, LA, RV, RA

    ! Declares the namelists
    namelist /INPUTS/ nstep, T, ncycle, pini_sys, pini_pulm, rk
    namelist /VALVES/ AV, MV, PV, TV
    namelist /ARTERIES/ scale_Rsys, scale_Csys, scale_Rpulm, scale_Cpulm, rho, sys, pulm
    namelist /HEART/ scale_EmaxLV, scale_EmaxRV, scale_Emax, LV, LA, RV, RA

    !!! Initialisation !!!
    ! Defines initial variables
    io = 42
    open(action='read', file='inputs.nml', newunit=io)
    read(nml=INPUTS, unit=io)
    read(nml=VALVES, unit=io)
    read(nml=ARTERIES, unit=io)
    read(nml=HEART, unit=io)
    close(io)

    headers = [ character(len=50) :: 'Aortic Valve Flow', &
        'Sinus Flow','Aortic Flow', &
        'Tricuspid Valve Flow', &
        'Pulmonary Valve Flow', &
        'Arterial Flow', &
        'Aterioles Flow', &
        'Mitral Valve Flow', &
        'Systemic Sinus Pressure', &
        'Systemic Artery Pressure', &
        'Systemic Venous Pressure', &
        'Pulmonary Sinus Pressure', &
        'Pulmonary Artery Pressure', &
        'Pulmonary Venous Pressure', &
        'Left Ventricular Volume', &
        'Left Atrial Volume', &
        'Right Ventricular Volume', &
        'Right Atrial Volume', &
        'Aortic Valve Status', &
        'Mitral Valve Status',&
        'Pulmonary Valve Status', &
        'Tricuspid Valve Status']

    ! Relevant arterial coefficients
    call artery_input(sys, pulm, scale_Rsys, scale_Csys, scale_Rpulm, scale_Cpulm)
    a_cof = arterial_network(sys, pulm, rho)

    ! Relevant heart coefficients
    call heart_input(LV, LA, RV, RA, T, scale_EmaxLV, scale_EmaxRV, scale_Emax)
    h_cof = chambers(LV, LA, RV, RA)

    ! Relevant valve coefficients
    v_cof = valve_system(AV, MV, PV, TV)

    !!! Main code !!!
    ! Calculates elastance curves for the different chambers of the heart
    allocate(t_axis(nstep))
    h = T / real(nstep, dp)
    t_val = 0.0_dp
    do i = 1, nstep
        t_axis(i) = t_val
        t_val = t_val + h
    end do
    allocate(ELV(nstep))
    allocate(ELA(nstep))
    allocate(ERV(nstep))
    allocate(ERA(nstep))
    ELV = calc_elastance(h_cof%LV, t_axis, 0.0_dp, 0.142_dp, 0.462_dp, 0.522_dp, .false.)
    ELA = calc_elastance(h_cof%LA, t_axis, 0.0_dp, 0.142_dp, 0.462_dp, 0.522_dp, .true.)
    ERV = calc_elastance(h_cof%RV, t_axis, 0.0_dp, 0.142_dp, 0.462_dp, 0.522_dp, .false.)
    ERA = calc_elastance(h_cof%RA, t_axis, 0.0_dp, 0.142_dp, 0.462_dp, 0.522_dp, .true.)

    ! Saves the heart information at the points
    elast = heart_elastance(ELV=ELV, ELA=ELA, ERV=ERV, ERA=ERA)
    elast_half = heart_elastance(ELV=midpoint(ELV), &
        ELA=midpoint(ELA), &
        ERV=midpoint(ERV), &
        ERA=midpoint(ERA))

    ! Initialise the solution
    allocate(sol(22, ncycle * nstep + 1))

    sol(1, 1) = 0.0_dp   ! Flow through aortic valve
    sol(2, 1) = 0.0_dp   ! Flow through sinus
    sol(3, 1) = 0.0_dp   ! Flow through aorta
    sol(4, 1) = 0.0_dp   ! Flow through tricuspid
    sol(5, 1) = 0.0_dp   ! Flow through pulmonary
    sol(6, 1) = 0.0_dp   ! Flow through arteries
    sol(7, 1) = 0.0_dp   ! Flow through arterioles
    sol(8, 1) = 0.0_dp   ! Flow through mitral valve

    sol(9, 1) = pini_sys    ! Initial arterial pressure
    sol(10, 1) = pini_sys    ! Initial arterial pressure
    sol(11, 1) = pini_sys    ! Initial arterial pressure
    sol(12, 1) = pini_pulm    ! Initial pulmonary pressure
    sol(13, 1) = pini_pulm    ! Initial pulmonary pressure
    sol(14, 1) = pini_pulm    ! Initial pulmonary pressure

    sol(15, 1) = h_cof%LV%v0_2    ! End diastolic left ventricular volume
    sol(16, 1) = h_cof%LA%v0_2    ! End diastolic left atrial volume
    sol(17, 1) = h_cof%RV%v0_2    ! End diastolic right ventricular volume
    sol(18, 1) = h_cof%RA%v0_2    ! End diastolic right atrial volume

    sol(19, 1) = 0.0_dp  ! Aortic valve is initially closed.
    sol(20, 1) = 0.0_dp  ! Mitral valve is initially closed.
    sol(21, 1) = 0.0_dp  ! Pulmonary valve is initially closed.
    sol(22, 1) = 0.0_dp  ! Tricuspid valve is initially closed.

    ! Solves the system of equations using a 4th order Runge-Kutta method
    i = 0 ! Initialise

    do icycle = 1, ncycle
        print *, 'Cycle: ', icycle
        do k = 1, nstep
            i = i + 1
            current_sol = sol(:, i)
            if (rk == 2) then ! Second order Runge-Kutta
                k1 = h * solver(current_sol, a_cof, v_cof, h_cof, elast, k)
                k2 = h * solver(current_sol + k1/2, a_cof, v_cof, h_cof, elast, k)
                sol(:, i+1) = current_sol + k2
            else if (rk == 4) then ! Fourth order Runge-Kutta
                k1 = h * solver(current_sol, a_cof, v_cof, h_cof, elast, k)
                k2 = h * solver(current_sol + k1/2, a_cof, v_cof, h_cof, elast, k)
                k3 = h * solver(current_sol + k2/2, a_cof, v_cof, h_cof, elast, k)
                if ( k /= nstep ) then
                    k4 = h * solver(current_sol + k3, a_cof, v_cof, h_cof, elast, k+1)
                else
                    k4 = h * solver(current_sol + k3, a_cof, v_cof, h_cof, elast, 1)
                end if
                sol(:, i + 1) = current_sol + (k1 + 2 * k2 + 2 * k3 + k4) / 6
            end if
        end do
    end do

    ! Calculates ventricular pressures
    allocate(h_pres(4, nstep))
    offset = (ncycle - 1) * nstep + 2
    h_pres(1, :) = ELV * (sol(15, offset:) - LV%v0_1)
    h_pres(2, :) = ELA * (sol(16, offset:) - LA%v0_1)
    h_pres(3, :) = ERV * (sol(17, offset:) - RV%v0_1)
    h_pres(4, :) = ERA * (sol(18, offset:) - RA%v0_1)

    ! Saves the solution
    io = 42
    nan_count = 0
    inf_count = 0
    open(newunit=io, file='output.csv', status='replace')
    do i=offset, ncycle * nstep
        do k=1, 22
            if ( i == offset ) then
                write(io, fmt="(A, A)", advance='no') trim(headers(k)), ','
                if ( k == 22 ) then
                    write(io, fmt="(A)", advance='no') 'Left Ventricular Pressure,'
                    write(io, fmt="(A)", advance='no') 'Left Atrial Pressure,'
                    write(io, fmt="(A)", advance='no') 'Right Ventricular Pressure,'
                    write(io, fmt="(A)", advance='no') 'Right Atrial Pressure,'
                    write(io, fmt="(A)", advance='no') 'Left Ventricular Elastance,'
                    write(io, fmt="(A)", advance='no') 'Left Atrial Elastance,'
                    write(io, fmt="(A)", advance='no') 'Right Ventricular Elastance,'
                    write(io, fmt="(A)", advance='no') 'Right Atrial Elastance,'
                    write(io, fmt="(A)", advance='no') 'Time (s)'
                end if
            else
                write(io, fmt="(f15.8, A)", advance='no') sol(k, i), ','
                if ( k == 22 ) then
                    write(io, fmt="(f15.8, A)", advance='no') h_pres(1, i - offset), ','
                    write(io, fmt="(f15.8, A)", advance='no') h_pres(2, i - offset), ','
                    write(io, fmt="(f15.8, A)", advance='no') h_pres(3, i - offset), ','
                    write(io, fmt="(f15.8, A)", advance='no') h_pres(4, i - offset), ','
                    write(io, fmt="(f15.8, A)", advance='no') ELV(i - offset), ','
                    write(io, fmt="(f15.8, A)", advance='no') ELA(i - offset), ','
                    write(io, fmt="(f15.8, A)", advance='no') ERV(i - offset), ','
                    write(io, fmt="(f15.8, A)", advance='no') ERA(i - offset), ','
                    write(io, fmt="(f15.8)", advance='no') t_axis(i - offset)
                end if

                if (ieee_is_nan(sol(k, i))) then
                    nan_count = nan_count + 1
                else if (.not. ieee_is_finite(sol(k, i))) then
                    inf_count = inf_count + 1
                end if
            end if
        end do
        write(io, *)  ! New line
    end do
    close(io)

    if (nan_count > 0) then
        print *, 'NaN values found in solution.'
        print *, '% NaN values:', 100.0_dp * nan_count / size(sol)
        print *, '% Inf values:', 100.0_dp * inf_count / size(sol)
    else
        print *, 'Converged!'
        print *, 'Mean value:', sum(sol) / size(sol)
    end if
end program main

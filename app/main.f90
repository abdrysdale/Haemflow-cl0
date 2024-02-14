program main
    
    use kind_parameter
    use data_types
    use inputs
    use funcs
    use ieee_arithmetic
    implicit none

    ! Declares initial variables
    integer :: nstep, ncycle, rk, i, icycle, k, io, nan_count, inf_count
    real(dp) :: T, pini_sys, pini_pulm, h, t_val
    type (arterial_network) :: a_cof
    type (chambers) :: h_cof
    type (valve) :: AV, MV, PV, TV
    real(dp), allocatable, dimension(:) :: ELV, ELA, ERV, ERA
    real(dp), allocatable :: sol(:, :)
    character(len=50), dimension(31) :: headers
    real(dp) :: scale_Rsys, scale_Csys, scale_Rpulm, scale_Cpulm
    real(dp) :: scale_Emax, scale_EmaxLV, scale_EmaxRV
    real(dp) :: rho
    type (arterial_system) :: sys
    type (arterial_system) :: pulm
    type (chamber) :: LV, LA, RV, RA
    real(dp) :: t1, t2, t3, t4
    type (thermal_system) :: therm


    ! Declares the namelists
    namelist /INPUTS/ nstep, T, ncycle, pini_sys, pini_pulm, rk
    namelist /VALVES/ AV, MV, PV, TV
    namelist /ARTERIES/ scale_Rsys, scale_Csys, scale_Rpulm, scale_Cpulm, rho, sys, pulm
    namelist /HEART/ scale_EmaxLV, scale_EmaxRV, scale_Emax, LV, LA, RV, RA
    namelist /ECG/ t1, t2, t3, t4
    namelist /THERMAL/ therm

    !!! Initialisation !!!
    ! Defines initial variables
    io = 42
    open(action='read', file='inputs.nml', newunit=io)
    read(nml=INPUTS, unit=io)
    read(nml=VALVES, unit=io)
    read(nml=ARTERIES, unit=io)
    read(nml=HEART, unit=io)
    read(nml=ECG, unit=io)
    read(nml=THERMAL, unit=io)
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
         'Tricuspid Valve Status', &
         'Left Ventricular Pressure', &
         'Left Atrial Pressure', &
         'Right Ventricular Pressure', &
         'Right Atrial Pressure', &
         'Left Ventricular Elastance', &
         'Left Atrial Elastance', &
         'Right Ventricular Elastance', &
         'Right Atrial Elastance', &
         'Time (s)']

    allocate(sol(31, nstep))
    sol = solve_system(nstep, &
         T, ncycle, rk, pini_sys, pini_pulm, &
         AV, MV, PV, TV, &
         scale_Rsys, scale_Csys, scale_Rpulm, scale_Cpulm, &
         rho, sys, pulm, &
         scale_EmaxLV, scale_EmaxRV, scale_Emax, &
         LV, LA, RV, RA, &
         t1, t2, t3, t4, &
         therm &
         )

    ! Saves the solution
    io = 42
    nan_count = 0
    inf_count = 0
    open(newunit=io, file='output.csv', status='replace')
    do i=1, nstep
        do k=1, 31
            if ( i == 1 ) then
                write(io, fmt="(A, A)", advance='no') trim(headers(k)), ','
            else
                write(io, fmt="(f15.8, A)", advance='no') sol(k, i), ','
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
        print *, 'Number of cycles:', ncycle
        print *, 'Mean value:', sum(sol) / size(sol)
    end if
end program main

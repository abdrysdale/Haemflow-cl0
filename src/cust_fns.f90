module cust_fns

    use kind_parameter
    implicit none

    private
    public midpoint

contains

    pure function midpoint(x) result(mp)

        ! Declares initial variables
        real(dp), allocatable, intent(in) :: x(:)
        integer :: i
        real(dp) :: dx(size(x) - 1)
        real(dp) :: mp(size(x) - 1)

        do i = 1, size(dx)
            dx(i) = x(i + 1) - x(i)
        end do
        mp = x(1:size(x)-1) + dx / 2
    end function midpoint
end module cust_fns

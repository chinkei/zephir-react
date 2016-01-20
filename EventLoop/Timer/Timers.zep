namespace React\EventLoop\Timer;

use SplObjectStorage;
use SplPriorityQueue;

class Timers
{
    private time;
    private timers;
    private scheduler;

    public function __construct()
    {
        let this->timers = new SplObjectStorage();
        let this->scheduler = new SplPriorityQueue();
    }

    public function updateTime()
    {
        let this->time = microtime(true);

        return this->time;
    }

    public function getTime()
    {
        var time;
        let time = ( this->time ? null : this->updateTime() );
        return time;
    }

    public function add(<TimerInterface> timer)
    {
        var interval, time, scheduledAt;
        let interval    = timer->getInterval();
        let time        = this->getTime();
        let scheduledAt = interval + time;

        this->timers->attach(timer, scheduledAt);
        this->scheduler->insert(timer, -scheduledAt);
    }

    public function contains(<TimerInterface> timer)
    {
        return this->timers->contains(timer);
    }

    public function cancel(<TimerInterface> timer)
    {
        this->timers->detach(timer);
    }

    public function getFirst()
    {
        while ( this->scheduler->count() ) {
            var timer = this->scheduler->top();

            if ( this->timers->contains(timer) ) {
                return this->timers[timer];
            }

            this->scheduler->extract();
        }

        return null;
    }

    public function isEmpty()
    {
        return count(this->timers) === 0;
    }

    public function tick()
    {
        var time   = this->updateTime();
        var timers = this->timers;
        var scheduler = this->scheduler;

        while ( !scheduler->isEmpty() ) {
            var timer = scheduler->top();

            if ( !isset(timers[timer]) ) {
                scheduler->extract();
                timers->detach(timer);

                continue;
            }

            if ( timers[timer] >= time ) {
                break;
            }

            scheduler->extract();
            call_user_func(timer->getCallback(), timer);

            if ( timer->isPeriodic() && isset(timers[timer]) ) {
                let timers[timer] = timer->getInterval() + time;
                var scheduledAt   = timers[timer];
                scheduler->insert(timer, -scheduledAt);
            } else {
                timers->detach(timer);
            }
        }
    }
}

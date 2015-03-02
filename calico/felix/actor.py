# Copyright (c) Metaswitch Networks 2015. All rights reserved.

import logging
import functools
import collections
import gevent
from gevent.event import AsyncResult
from gevent.queue import Queue, Full

_log = logging.getLogger(__name__)


DEFAULT_QUEUE_SIZE = 10


Message = collections.namedtuple("Message", ("function", "result"))


class Actor(object):

    def __init__(self, queue_size=DEFAULT_QUEUE_SIZE):
        self._event_queue = Queue(maxsize=queue_size)
        self.greenlet = gevent.Greenlet(self._loop)

    def start(self):
        assert not self.greenlet, "Already running"
        _log.debug("Starting %s", self)
        self.greenlet.start()
        return self

    def _loop(self):
        while True:
            msg = self._event_queue.get()
            assert isinstance(msg.result, AsyncResult)
            try:
                result = msg.function()
            except BaseException as e:
                _log.exception("Exception on loop")
                msg.result.set_exception(e)
            else:
                msg.result.set(result)


def actor_event(fn):
    @functools.wraps(fn)
    def queue_fn(self, *args, **kwargs):
        result = AsyncResult()
        partial = functools.partial(fn, self, *args, **kwargs)
        self._event_queue.put(Message(function=partial, result=result),
                              block=self.greenlet)
        return result
    return queue_fn

